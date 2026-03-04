Set-StrictMode -Version Latest

Describe 'Add/Remove Purview Collection Role Member cmdlets' {
    BeforeAll {
        . "$PSScriptRoot\..\Public\Add-PurviewCollectionRoleMember.ps1"
        . "$PSScriptRoot\..\Public\Remove-PurviewCollectionRoleMember.ps1"
    }

    It 'Add skips role validation when SkipRoleValidation is supplied' {
        $script:roleCheckCount = 0
        $policy = [pscustomobject]@{ id = 'policy-1' }

        function script:Test-PurviewMetadataRoleExists { $script:roleCheckCount++; $true }
        function script:Get-PurviewMetadataRoleIds { @('role1') }
        function script:Get-PurviewMetadataPolicy { param($AccountName, $CollectionName) $policy }
        function script:Update-PurviewPolicyRoleMemberInternal { [pscustomobject]@{ Updated = $false; Policy = $policy } }
        function script:Update-PurviewMetadataPolicy { throw 'Should not be called when no update is needed' }

        Add-PurviewCollectionRoleMember -AccountName 'acct' -CollectionName 'abc123' -RoleId 'role1' -PrincipalId 'p1' -SkipRoleValidation -Confirm:$false

        $script:roleCheckCount | Should -Be 0

        Remove-Item function:script:Test-PurviewMetadataRoleExists -ErrorAction SilentlyContinue
        Remove-Item function:script:Get-PurviewMetadataRoleIds -ErrorAction SilentlyContinue
        Remove-Item function:script:Get-PurviewMetadataPolicy -ErrorAction SilentlyContinue
        Remove-Item function:script:Update-PurviewPolicyRoleMemberInternal -ErrorAction SilentlyContinue
        Remove-Item function:script:Update-PurviewMetadataPolicy -ErrorAction SilentlyContinue
    }

    It 'Add throws a helpful error when RoleId validation fails' {
        function script:Test-PurviewMetadataRoleExists { $false }
        function script:Get-PurviewMetadataRoleIds { @('role-a', 'role-b') }

        $caught = $null
        try {
            Add-PurviewCollectionRoleMember -AccountName 'acct' -CollectionName 'abc123' -RoleId 'missing-role' -PrincipalId 'p1' -Confirm:$false
        }
        catch {
            $caught = $_
        }

        ($null -ne $caught) | Should -Be $true
        ($caught.Exception.Message -match "Role 'missing-role' does not exist") | Should -Be $true
        ($caught.Exception.Message -match 'role-a') | Should -Be $true

        Remove-Item function:script:Test-PurviewMetadataRoleExists -ErrorAction SilentlyContinue
        Remove-Item function:script:Get-PurviewMetadataRoleIds -ErrorAction SilentlyContinue
    }

    It 'Add does not push policy update when WhatIf is used' {
        $script:updateCallCount = 0
        $policy = [pscustomobject]@{ id = 'policy-2' }

        function script:Test-PurviewMetadataRoleExists { $true }
        function script:Get-PurviewMetadataPolicy { param($AccountName, $CollectionName) $policy }
        function script:Update-PurviewPolicyRoleMemberInternal { [pscustomobject]@{ Updated = $true; Policy = $policy } }
        function script:Update-PurviewMetadataPolicy { $script:updateCallCount++ }

        Add-PurviewCollectionRoleMember -AccountName 'acct' -CollectionName 'abc123' -RoleId 'role-a' -PrincipalId 'p1' -WhatIf

        $script:updateCallCount | Should -Be 0

        Remove-Item function:script:Test-PurviewMetadataRoleExists -ErrorAction SilentlyContinue
        Remove-Item function:script:Get-PurviewMetadataPolicy -ErrorAction SilentlyContinue
        Remove-Item function:script:Update-PurviewPolicyRoleMemberInternal -ErrorAction SilentlyContinue
        Remove-Item function:script:Update-PurviewMetadataPolicy -ErrorAction SilentlyContinue
    }

    It 'Add throws when updated policy does not contain an ID' {
        function script:Test-PurviewMetadataRoleExists { $true }
        function script:Get-PurviewMetadataPolicy { [pscustomobject]@{ id = 'orig-policy' } }
        function script:Update-PurviewPolicyRoleMemberInternal { [pscustomobject]@{ Updated = $true; Policy = [pscustomobject]@{} } }
        function script:Update-PurviewMetadataPolicy { throw 'Should not be called when policy id is missing' }

        $caught = $null
        try {
            Add-PurviewCollectionRoleMember -AccountName 'acct' -CollectionName 'abc123' -RoleId 'role-a' -PrincipalId 'p1' -Confirm:$false
        }
        catch {
            $caught = $_
        }

        ($null -ne $caught) | Should -Be $true
        ($caught.Exception.Message -match 'Could not determine Policy ID') | Should -Be $true

        Remove-Item function:script:Test-PurviewMetadataRoleExists -ErrorAction SilentlyContinue
        Remove-Item function:script:Get-PurviewMetadataPolicy -ErrorAction SilentlyContinue
        Remove-Item function:script:Update-PurviewPolicyRoleMemberInternal -ErrorAction SilentlyContinue
        Remove-Item function:script:Update-PurviewMetadataPolicy -ErrorAction SilentlyContinue
    }

    It 'Remove does not push update when no policy change is needed' {
        $script:updateCallCount = 0
        $policy = [pscustomobject]@{ id = 'policy-3' }

        function script:Test-PurviewMetadataRoleExists { $true }
        function script:Get-PurviewMetadataPolicy { param($AccountName, $CollectionName) $policy }
        function script:Update-PurviewPolicyRoleMemberInternal { [pscustomobject]@{ Updated = $false; Policy = $policy } }
        function script:Update-PurviewMetadataPolicy { $script:updateCallCount++ }

        Remove-PurviewCollectionRoleMember -AccountName 'acct' -CollectionName 'abc123' -RoleId 'role-a' -PrincipalId 'p1' -Confirm:$false

        $script:updateCallCount | Should -Be 0

        Remove-Item function:script:Test-PurviewMetadataRoleExists -ErrorAction SilentlyContinue
        Remove-Item function:script:Get-PurviewMetadataPolicy -ErrorAction SilentlyContinue
        Remove-Item function:script:Update-PurviewPolicyRoleMemberInternal -ErrorAction SilentlyContinue
        Remove-Item function:script:Update-PurviewMetadataPolicy -ErrorAction SilentlyContinue
    }

    It 'Remove does not push policy update when WhatIf is used' {
        $script:updateCallCount = 0
        $policy = [pscustomobject]@{ id = 'policy-4' }

        function script:Test-PurviewMetadataRoleExists { $true }
        function script:Get-PurviewMetadataPolicy { param($AccountName, $CollectionName) $policy }
        function script:Update-PurviewPolicyRoleMemberInternal { [pscustomobject]@{ Updated = $true; Policy = $policy } }
        function script:Update-PurviewMetadataPolicy { $script:updateCallCount++ }

        Remove-PurviewCollectionRoleMember -AccountName 'acct' -CollectionName 'abc123' -RoleId 'role-a' -PrincipalId 'p1' -WhatIf

        $script:updateCallCount | Should -Be 0

        Remove-Item function:script:Test-PurviewMetadataRoleExists -ErrorAction SilentlyContinue
        Remove-Item function:script:Get-PurviewMetadataPolicy -ErrorAction SilentlyContinue
        Remove-Item function:script:Update-PurviewPolicyRoleMemberInternal -ErrorAction SilentlyContinue
        Remove-Item function:script:Update-PurviewMetadataPolicy -ErrorAction SilentlyContinue
    }
}
