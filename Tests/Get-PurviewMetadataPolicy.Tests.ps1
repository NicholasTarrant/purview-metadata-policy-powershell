Set-StrictMode -Version Latest

Describe 'Get-PurviewMetadataPolicy' {
    BeforeAll {
        . "$PSScriptRoot\..\Public\Get-PurviewMetadataPolicy.ps1"
    }

    It 'returns values array for ListAll parameter set' {
        $script:capturedUri = $null

        function script:Invoke-PurviewRestMethod {
            param(
                [string]$AccountName,
                [string]$UriSuffix,
                [string]$Method
            )

            $script:capturedUri = $UriSuffix
            [pscustomobject]@{
                values = @(
                    [pscustomobject]@{ id = 'p1' },
                    [pscustomobject]@{ id = 'p2' }
                )
            }
        }

        $result = Get-PurviewMetadataPolicy -AccountName 'acct'

        @($result).Count | Should -Be 2
        $script:capturedUri | Should -Be '/policystore/metadataPolicies'

        Remove-Item function:script:Invoke-PurviewRestMethod -ErrorAction SilentlyContinue
    }

    It 'builds policy id URI for ByPolicyId parameter set' {
        $script:capturedUri = $null

        function script:Invoke-PurviewRestMethod {
            param(
                [string]$AccountName,
                [string]$UriSuffix,
                [string]$Method
            )

            $script:capturedUri = $UriSuffix
            [pscustomobject]@{ id = 'policy-123' }
        }

        $result = Get-PurviewMetadataPolicy -AccountName 'acct' -PolicyId 'policy-123'

        $result.id | Should -Be 'policy-123'
        $script:capturedUri | Should -Be '/policystore/metadataPolicies/policy-123'

        Remove-Item function:script:Invoke-PurviewRestMethod -ErrorAction SilentlyContinue
    }

    It 'resolves collection name and builds collection metadata policy URI' {
        $script:capturedUri = $null
        $script:resolveInput = $null

        function script:Resolve-PurviewCollectionName {
            param(
                [string]$AccountName,
                [string]$CollectionName
            )

            $script:resolveInput = $CollectionName
            'abc123'
        }

        function script:Invoke-PurviewRestMethod {
            param(
                [string]$AccountName,
                [string]$UriSuffix,
                [string]$Method
            )

            $script:capturedUri = $UriSuffix
            [pscustomobject]@{ id = 'policy-collection' }
        }

        $result = Get-PurviewMetadataPolicy -AccountName 'acct' -CollectionName 'Finance Team'

        $result.id | Should -Be 'policy-collection'
        $script:resolveInput | Should -Be 'Finance Team'
        $script:capturedUri | Should -Be '/policystore/collections/abc123/metadataPolicy'

        Remove-Item function:script:Resolve-PurviewCollectionName -ErrorAction SilentlyContinue
        Remove-Item function:script:Invoke-PurviewRestMethod -ErrorAction SilentlyContinue
    }
}
