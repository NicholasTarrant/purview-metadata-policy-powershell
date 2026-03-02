Set-StrictMode -Version Latest

Describe 'Update-PurviewPolicyRoleMemberInternal - exact role matching' {
    BeforeAll {
        . "$PSScriptRoot\..\Private\Update-PurviewPolicyRoleMemberInternal.ps1"
    }

    It 'updates only the rule whose derived.purview.role exactly matches RoleId' {
        $targetRoleId = 'purviewmetadatarole_builtin_data-curator'
        $principalId = '00000000-0000-0000-0000-000000000001'

        $policy = [pscustomobject]@{
            properties = [pscustomobject]@{
                attributeRules = @(
                    [pscustomobject]@{
                        id = 'rule-target'
                        name = 'rule-target'
                        dnfCondition = @(
                            @(
                                [pscustomobject]@{
                                    attributeName = 'principal.microsoft.id'
                                    attributeValueIncludedIn = @()
                                },
                                [pscustomobject]@{
                                    attributeName = 'derived.purview.role'
                                    attributeValueIncludes = $targetRoleId
                                }
                            )
                        )
                    },
                    [pscustomobject]@{
                        id = 'rule-non-target'
                        name = 'rule-non-target'
                        dnfCondition = @(
                            @(
                                [pscustomobject]@{
                                    attributeName = 'principal.microsoft.id'
                                    attributeValueIncludedIn = @()
                                },
                                [pscustomobject]@{
                                    attributeName = 'derived.purview.role'
                                    attributeValueIncludes = "$targetRoleId-extra"
                                }
                            )
                        )
                    }
                )
            }
        }

        $result = Update-PurviewPolicyRoleMemberInternal -Policy $policy -RoleId $targetRoleId -PrincipalId $principalId -Action Add -PrincipalType User

        $targetPrincipalCondition = $result.Policy.properties.attributeRules[0].dnfCondition[0] |
            Where-Object { $_.attributeName -eq 'principal.microsoft.id' }
        $nonTargetPrincipalCondition = $result.Policy.properties.attributeRules[1].dnfCondition[0] |
            Where-Object { $_.attributeName -eq 'principal.microsoft.id' }

        $result.Updated | Should -Be $true
        (@($targetPrincipalCondition.attributeValueIncludedIn) -contains $principalId) | Should -Be $true
        @($nonTargetPrincipalCondition.attributeValueIncludedIn).Count | Should -Be 0
    }

    It 'does not update when only partial role text matches another rule' {
        $policy = [pscustomobject]@{
            properties = [pscustomobject]@{
                attributeRules = @(
                    [pscustomobject]@{
                        id = 'rule-only-partial'
                        name = 'rule-only-partial'
                        dnfCondition = @(
                            @(
                                [pscustomobject]@{
                                    attributeName = 'principal.microsoft.id'
                                    attributeValueIncludedIn = @()
                                },
                                [pscustomobject]@{
                                    attributeName = 'derived.purview.role'
                                    attributeValueIncludes = 'purviewmetadatarole_builtin_data-curator-extra'
                                }
                            )
                        )
                    }
                )
            }
        }

        $result = Update-PurviewPolicyRoleMemberInternal -Policy $policy -RoleId 'purviewmetadatarole_builtin_data-curator' -PrincipalId '00000000-0000-0000-0000-000000000002' -Action Add -PrincipalType User

        $result.Updated | Should -Be $false
    }

    It 'keeps attributeValueIncludedIn as array after remove leaves one member' {
        $targetRoleId = 'purviewmetadatarole_builtin_purview-reader'

        $policy = [pscustomobject]@{
            properties = [pscustomobject]@{
                attributeRules = @(
                    [pscustomobject]@{
                        id = 'rule-reader'
                        name = 'rule-reader'
                        dnfCondition = @(
                            @(
                                [pscustomobject]@{
                                    attributeName = 'principal.microsoft.id'
                                    attributeValueIncludedIn = @(
                                        '00000000-0000-0000-0000-000000000111',
                                        '00000000-0000-0000-0000-000000000222'
                                    )
                                },
                                [pscustomobject]@{
                                    attributeName = 'derived.purview.role'
                                    attributeValueIncludes = $targetRoleId
                                }
                            )
                        )
                    }
                )
            }
        }

        $result = Update-PurviewPolicyRoleMemberInternal -Policy $policy -RoleId $targetRoleId -PrincipalId '00000000-0000-0000-0000-000000000222' -Action Remove -PrincipalType User

        $principalCondition = $result.Policy.properties.attributeRules[0].dnfCondition[0] |
            Where-Object { $_.attributeName -eq 'principal.microsoft.id' }

        $result.Updated | Should -Be $true
        @($principalCondition.attributeValueIncludedIn).Count | Should -Be 1
        $principalCondition.attributeValueIncludedIn.GetType().Name | Should -Be 'Object[]'
    }
}
