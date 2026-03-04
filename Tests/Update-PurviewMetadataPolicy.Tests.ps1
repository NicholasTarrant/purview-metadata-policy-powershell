Set-StrictMode -Version Latest

Describe 'Update-PurviewMetadataPolicy' {
    BeforeAll {
        . "$PSScriptRoot\..\Public\Update-PurviewMetadataPolicy.ps1"
    }

    It 'calls Invoke-PurviewRestMethod with PUT and serialized body' {
        $script:captured = [ordered]@{}

        function script:Invoke-PurviewRestMethod {
            param(
                [string]$AccountName,
                [string]$UriSuffix,
                [string]$Method,
                [string]$Body
            )

            $script:captured.AccountName = $AccountName
            $script:captured.UriSuffix = $UriSuffix
            $script:captured.Method = $Method
            $script:captured.Body = $Body

            [pscustomobject]@{ status = 'ok' }
        }

        $policy = [pscustomobject]@{
            id = 'policy-1'
            properties = [pscustomobject]@{
                attributeRules = @(
                    [pscustomobject]@{ id = 'r1' }
                )
            }
        }

        $result = Update-PurviewMetadataPolicy -AccountName 'acct' -PolicyId 'policy-1' -PolicyObject $policy -Confirm:$false

        $result.status | Should -Be 'ok'
        $script:captured.AccountName | Should -Be 'acct'
        $script:captured.UriSuffix | Should -Be '/policystore/metadataPolicies/policy-1'
        $script:captured.Method | Should -Be 'PUT'
        ($script:captured.Body -match '"id":"policy-1"') | Should -Be $true

        Remove-Item function:script:Invoke-PurviewRestMethod -ErrorAction SilentlyContinue
    }

    It 'does not call Invoke-PurviewRestMethod when WhatIf is used' {
        $script:callCount = 0

        function script:Invoke-PurviewRestMethod {
            $script:callCount++
            throw 'Should not be called under WhatIf'
        }

        $policy = [pscustomobject]@{ id = 'policy-2' }

        $result = Update-PurviewMetadataPolicy -AccountName 'acct' -PolicyId 'policy-2' -PolicyObject $policy -WhatIf

        $script:callCount | Should -Be 0
        $null -eq $result | Should -Be $true

        Remove-Item function:script:Invoke-PurviewRestMethod -ErrorAction SilentlyContinue
    }
}
