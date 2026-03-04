Set-StrictMode -Version Latest

Describe 'Metadata role helpers' {
    BeforeAll {
        . "$PSScriptRoot\..\Public\Get-PurviewMetadataRole.ps1"
        . "$PSScriptRoot\..\Private\Get-PurviewMetadataRoleIds.ps1"
        . "$PSScriptRoot\..\Private\Test-PurviewMetadataRoleExists.ps1"
    }

    It 'Get-PurviewMetadataRole returns values from API response' {
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
                    [pscustomobject]@{ id = 'role-a'; name = 'Role A' },
                    [pscustomobject]@{ id = 'role-b'; name = 'Role B' }
                )
            }
        }

        $roles = Get-PurviewMetadataRole -AccountName 'acct'

        @($roles).Count | Should -Be 2
        $script:capturedUri | Should -Be '/policystore/metadataroles'

        Remove-Item function:script:Invoke-PurviewRestMethod -ErrorAction SilentlyContinue
    }

    It 'Get-PurviewMetadataRoleIds returns flat list of role ids' {
        function script:Get-PurviewMetadataRole {
            @(
                [pscustomobject]@{ id = 'role-a' },
                [pscustomobject]@{ id = 'role-b' }
            )
        }

        $ids = Get-PurviewMetadataRoleIds -AccountName 'acct'

        @($ids).Count | Should -Be 2
        $ids[0] | Should -Be 'role-a'
        $ids[1] | Should -Be 'role-b'

        Remove-Item function:script:Get-PurviewMetadataRole -ErrorAction SilentlyContinue
    }

    It 'Test-PurviewMetadataRoleExists returns true when role id matches' {
        function script:Get-PurviewMetadataRole {
            @(
                [pscustomobject]@{ id = 'role-a'; name = 'Role A' }
            )
        }

        $result = Test-PurviewMetadataRoleExists -AccountName 'acct' -RoleId 'role-a'

        $result | Should -Be $true

        Remove-Item function:script:Get-PurviewMetadataRole -ErrorAction SilentlyContinue
    }

    It 'Test-PurviewMetadataRoleExists returns true when role name matches' {
        function script:Get-PurviewMetadataRole {
            @(
                [pscustomobject]@{ id = 'role-a'; name = 'Role A' }
            )
        }

        $result = Test-PurviewMetadataRoleExists -AccountName 'acct' -RoleId 'Role A'

        $result | Should -Be $true

        Remove-Item function:script:Get-PurviewMetadataRole -ErrorAction SilentlyContinue
    }

    It 'Test-PurviewMetadataRoleExists returns false when role is absent' {
        function script:Get-PurviewMetadataRole {
            @(
                [pscustomobject]@{ id = 'role-a'; name = 'Role A' }
            )
        }

        $result = Test-PurviewMetadataRoleExists -AccountName 'acct' -RoleId 'role-x'

        $result | Should -Be $false

        Remove-Item function:script:Get-PurviewMetadataRole -ErrorAction SilentlyContinue
    }

    It 'Test-PurviewMetadataRoleExists wraps and rethrows lookup errors' {
        Mock Get-PurviewMetadataRole {
            throw 'lookup failed'
        }

        $caught = $null
        try {
            Test-PurviewMetadataRoleExists -AccountName 'acct' -RoleId 'role-a'
        }
        catch {
            $caught = $_
        }

        ($null -ne $caught) | Should -Be $true
        ($caught.Exception.Message -match "Failed to validate role 'role-a'") | Should -Be $true
        ($caught.Exception.Message -match 'lookup failed') | Should -Be $true
    }
}
