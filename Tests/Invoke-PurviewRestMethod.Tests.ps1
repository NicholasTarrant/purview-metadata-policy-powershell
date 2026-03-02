Set-StrictMode -Version Latest

Describe 'Invoke-PurviewRestMethod - error shaping' {
    BeforeAll {
        . "$PSScriptRoot\..\Private\Invoke-PurviewRestMethod.ps1"
    }

    It 'returns HTTP unknown when exception has no response status' {
        function script:Get-AzAccessToken {
            param([string]$ResourceUrl)
            [pscustomobject]@{ Token = 'fake-token' }
        }

        function script:Invoke-RestMethod {
            throw ([System.Exception]::new('network down'))
        }

        $caught = $null
        try {
            Invoke-PurviewRestMethod -AccountName 'contoso' -UriSuffix '/policystore/metadataPolicies' -Method GET
        }
        catch {
            $caught = $_
        }

        ($null -ne $caught) | Should Be $true
        $message = $caught.Exception.Message

        ($message -match 'Purview API error') | Should Be $true
        ($message -like '*HTTP*unknown*') | Should Be $true
        ($message -match 'network down') | Should Be $true
        ($message -match 'GET https://contoso\.purview\.azure\.com/policystore/metadataPolicies\?api-version=2021-07-01') | Should Be $true

        Remove-Item function:script:Get-AzAccessToken -ErrorAction SilentlyContinue
        Remove-Item function:script:Invoke-RestMethod -ErrorAction SilentlyContinue
    }

    It 'includes provided API version in shaped error message' {
        function script:Get-AzAccessToken {
            param([string]$ResourceUrl)
            [pscustomobject]@{ Token = 'fake-token' }
        }

        function script:Invoke-RestMethod {
            throw ([System.Exception]::new('request failed'))
        }

        $caught = $null
        try {
            Invoke-PurviewRestMethod -AccountName 'contoso' -UriSuffix 'account/collections' -Method GET -ApiVersion '2019-11-01-preview'
        }
        catch {
            $caught = $_
        }

        ($null -ne $caught) | Should Be $true
        $message = $caught.Exception.Message

        ($message -match 'api-version=2019-11-01-preview') | Should Be $true
        ($message -match 'request failed') | Should Be $true

        Remove-Item function:script:Get-AzAccessToken -ErrorAction SilentlyContinue
        Remove-Item function:script:Invoke-RestMethod -ErrorAction SilentlyContinue
    }
}
