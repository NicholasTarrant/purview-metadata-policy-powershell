Set-StrictMode -Version Latest

Describe 'Resolve-PurviewCollectionName' {
    BeforeAll {
        . "$PSScriptRoot\..\Private\Resolve-PurviewCollectionName.ps1"
    }

    It 'returns system name directly without API call' {
        $script:invokeCount = 0
        function script:Invoke-PurviewRestMethod {
            $script:invokeCount++
            throw 'Should not be called for system name input.'
        }

        $result = Resolve-PurviewCollectionName -AccountName 'acct' -CollectionName 'abc123'

        $result | Should Be 'abc123'
        $script:invokeCount | Should Be 0

        Remove-Item function:script:Invoke-PurviewRestMethod -ErrorAction SilentlyContinue
    }

    It 'resolves friendly name across paged collection results' {
        $script:invokeCount = 0
        function script:Invoke-PurviewRestMethod {
            param(
                [string]$AccountName,
                [string]$UriSuffix,
                [string]$Method,
                [string]$ApiVersion
            )

            $script:invokeCount++

            if ($UriSuffix -eq 'account/collections') {
                return [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{ friendlyName = 'Finance Team'; name = 'fin001' }
                    )
                    nextLink = 'https://acct.purview.azure.com/account/collections?skipToken=next'
                }
            }

            if ($UriSuffix -eq 'account/collections?skipToken=next') {
                return [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{ friendlyName = 'Engineering'; name = 'eng999' }
                    )
                    nextLink = $null
                }
            }

            throw "Unexpected UriSuffix: $UriSuffix"
        }

        $result = Resolve-PurviewCollectionName -AccountName 'acct' -CollectionName 'Engineering'

        $result | Should Be 'eng999'
        $script:invokeCount | Should Be 2

        Remove-Item function:script:Invoke-PurviewRestMethod -ErrorAction SilentlyContinue
    }

    It 'throws when friendly name is ambiguous' {
        function script:Invoke-PurviewRestMethod {
            [pscustomobject]@{
                value = @(
                    [pscustomobject]@{ friendlyName = 'Finance Team'; name = 'fin001' },
                    [pscustomobject]@{ friendlyName = 'Finance Team'; name = 'fin002' }
                )
                nextLink = $null
            }
        }

        $caught = $null
        try {
            Resolve-PurviewCollectionName -AccountName 'acct' -CollectionName 'Finance Team'
        }
        catch {
            $caught = $_
        }

        ($null -ne $caught) | Should Be $true
        ($caught.Exception.Message -match 'Multiple Purview collections matched') | Should Be $true

        Remove-Item function:script:Invoke-PurviewRestMethod -ErrorAction SilentlyContinue
    }
}
