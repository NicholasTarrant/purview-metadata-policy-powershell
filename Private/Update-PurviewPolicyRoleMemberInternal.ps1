function Find-PrincipalConditionEntry {
    <#
    .SYNOPSIS
    Finds the condition entry in a rule's dnfCondition that matches the given attributeName.

    .DESCRIPTION
    Each attributeRule has a dnfCondition which is an array of OR clauses.
    Each OR clause is an array of AND conditions (AttributeMatchers).

    Common attributeNames in Purview metadata policies:
    - principal.microsoft.id        : User or Service Principal Object IDs
    - principal.microsoft.groups.id : Entra ID Group Object IDs (transitive membership)
    - derived.purview.role          : The role binding (e.g., purviewmetadatarole_builtin_collection-administrator)
    - derived.purview.permission    : Inherited permissions from parent collections

    Returns the first matching condition term and its clause index, or $null if not found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$RuleConfig,

        [Parameter(Mandatory = $true)]
        [string]$AttributeName
    )
    
    if ($null -ne $RuleConfig.dnfCondition) {
        for ($clauseIdx = 0; $clauseIdx -lt $RuleConfig.dnfCondition.Count; $clauseIdx++) {
            $clause = $RuleConfig.dnfCondition[$clauseIdx]
            foreach ($term in $clause) {
                if ($term.attributeName -eq $AttributeName) {
                    return @{ Term = $term; ClauseIndex = $clauseIdx }
                }
            }
        }
    }
    return $null
}

function Update-PurviewPolicyRoleMemberInternal {
    <#
    .SYNOPSIS
    Internal helper to add or remove a principal from a role's attributeRule in a Purview metadata policy.

    .DESCRIPTION
    Updates the dnfCondition array structure within the matching attributeRule.

    dnfCondition structure for a role rule (e.g., collection-administrator):
    [
        [  # First OR clause - explicit principal assignment
            { attributeName: "principal.microsoft.id", attributeValueIncludedIn: ["guid1", "guid2"] },
            { attributeName: "derived.purview.role", attributeValueIncludes: "purviewmetadatarole_builtin_..." }
        ],
        [  # Second OR clause - inherited from parent (read-only, managed by Purview)
            { attributeName: "derived.purview.permission", attributeValueIncludes: "..." }
        ]
    ]

    For groups, use attributeName "principal.microsoft.groups.id" instead of "principal.microsoft.id".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Policy,

        [Parameter(Mandatory = $true)]
        [string]$RoleId,

        [Parameter(Mandatory = $true)]
        [string]$PrincipalId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Add', 'Remove')]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [ValidateSet('User', 'Group')]
        [string]$PrincipalType = 'User'
    )

    $updated = $false
    
    # Determine the attribute name based on principal type
    $principalAttributeName = switch ($PrincipalType) {
        'User'  { 'principal.microsoft.id' }
        'Group' { 'principal.microsoft.groups.id' }
    }

    # Depending on API version, the rules might be on the root or under properties.attributeRules
    $rulesArray = $null
    if ($null -ne $Policy.properties -and $null -ne $Policy.properties.attributeRules) {
        $rulesArray = $Policy.properties.attributeRules
    } elseif ($null -ne $Policy.attributeRules) {
        $rulesArray = $Policy.attributeRules
    }

    if ($null -eq $rulesArray) {
        throw "Could not find 'attributeRules' in the policy object. The policy structure may be unexpected."
    }

    # Find the role rule
    $roleRule = $null
    foreach ($rule in $rulesArray) {
        $matched = $false

        if ($rule.id -eq $RoleId -or $rule.name -eq $RoleId) {
            $matched = $true
        }
        elseif ($null -ne $rule.dnfCondition) {
            foreach ($clause in $rule.dnfCondition) {
                foreach ($term in $clause) {
                    if ($term.attributeName -eq 'derived.purview.role' -and $term.attributeValueIncludes -eq $RoleId) {
                        $matched = $true
                        break
                    }
                }
                if ($matched) { break }
            }
        }

        if ($matched) {
            $roleRule = $rule
            break
        }
    }

    if ($null -eq $roleRule) {
        if ($Action -eq 'Add') {
            Write-Warning "Role ID '$RoleId' not found in policy. Cannot add."
        }
        return @{ Policy = $Policy; Updated = $false }
    }

    $principalConditionResult = Find-PrincipalConditionEntry -RuleConfig $roleRule -AttributeName $principalAttributeName

    if ($null -eq $principalConditionResult) {
        if ($Action -eq 'Add') {
            Write-Verbose "Could not find '$principalAttributeName' condition block for role '$RoleId'. Creating a new one..."
            
            # Create a new condition format exactly as expected by the payload.
            # dnfCondition is an array of OR clauses. Each OR clause is an array of AND conditions.
            # For a new principal assignment, we need:
            #   - The principal ID condition
            #   - The derived.purview.role binding condition
            $newPrincipalCondition = [ordered]@{
                attributeName = $principalAttributeName
                attributeValueIncludedIn = @($PrincipalId)
            }
            
            $newRoleCondition = [ordered]@{
                attributeName = 'derived.purview.role'
                attributeValueIncludes = $RoleId
            }
            
            if ($null -eq $roleRule.dnfCondition) {
                # Add entirely new dnfCondition structure with both conditions in the same AND clause
                $roleRule | Add-Member -MemberType NoteProperty -Name dnfCondition -Value @( ,@( $newPrincipalCondition, $newRoleCondition ) )
            } else {
                # Find or create the first OR clause that has the role binding, then add the principal condition there
                # If there's already a clause with derived.purview.role, add to it; otherwise create a new clause
                $foundRoleClause = $false
                for ($i = 0; $i -lt $roleRule.dnfCondition.Count; $i++) {
                    $clause = $roleRule.dnfCondition[$i]
                    foreach ($term in $clause) {
                        if ($term.attributeName -eq 'derived.purview.role') {
                            # Found the role binding clause, add principal condition here
                            $roleRule.dnfCondition[$i] = @($clause) + @($newPrincipalCondition)
                            $foundRoleClause = $true
                            break
                        }
                    }
                    if ($foundRoleClause) { break }
                }
                
                if (-not $foundRoleClause) {
                    # No existing role clause found, prepend a new OR clause
                    $roleRule.dnfCondition = @( ,@( $newPrincipalCondition, $newRoleCondition ) ) + $roleRule.dnfCondition
                }
            }
            $updated = $true
            return @{ Policy = $Policy; Updated = $updated }
        } else {
            Write-Verbose "Principal condition block '$principalAttributeName' does not exist, nothing to remove."
            return @{ Policy = $Policy; Updated = $false }
        }
    }
    
    # Extract the actual condition term from the result
    $principalCondition = $principalConditionResult.Term

    # Ensure attributeValueIncludedIn is an array
    if ($null -eq $principalCondition.attributeValueIncludedIn) {
        $principalCondition.attributeValueIncludedIn = @()
    }

    # It could be a PSObject array, we work with it as an array list
    $currentMembers = @($principalCondition.attributeValueIncludedIn)

    if ($Action -eq 'Add') {
        if ($PrincipalId -notin $currentMembers) {
            $currentMembers += $PrincipalId
            $updated = $true
        } else {
            Write-Verbose "Principal '$PrincipalId' already in '$RoleId'."
        }
    } else {
        # Remove
        if ($PrincipalId -in $currentMembers) {
            $currentMembers = $currentMembers | Where-Object { $_ -ne $PrincipalId }
            $updated = $true
        } else {
            Write-Verbose "Principal '$PrincipalId' not found in '$RoleId'."
        }
    }

    if ($updated) {
        $principalCondition.attributeValueIncludedIn = @($currentMembers)
        Write-Verbose "Successfully updated members array."
    }

    return @{ Policy = $Policy; Updated = $updated }
}
