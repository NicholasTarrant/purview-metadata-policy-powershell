function Add-PurviewCollectionRoleMember {
    <#
    .SYNOPSIS
    Adds a principal to a role in a Microsoft Purview collection's metadata policy.

    .DESCRIPTION
    Retrieves the current metadata policy for the specified collection, adds the principal to
    the designated role's attribute rule, then commits the updated policy back to Purview via PUT.

    Accepted principal types:
    - User (default): users and service principals, stored under 'principal.microsoft.id'
    - Group: Entra ID security groups with transitive membership, stored under
      'principal.microsoft.groups.id'

    This function is idempotent. If the principal already holds the role, no API write is made
    and the function completes silently. Use -Verbose to observe the no-op.

    .PARAMETER AccountName
    The name of the Microsoft Purview account (the subdomain portion of
    https://<AccountName>.purview.azure.com).

    .PARAMETER CollectionName
    The collection to assign the role on. Accepts either the 6-character system name
    (e.g. 'abc123') or the friendly display name (e.g. 'Finance Team'). Friendly names
    are resolved automatically via the account/collections API. Pass the system name
    directly to avoid that extra API call in performance-sensitive loops.

    .PARAMETER RoleId
    The fully-qualified Purview metadata role ID. Use Get-PurviewMetadataRole to list
    available roles. Built-in role IDs follow the pattern:
    'purviewmetadatarole_builtin_<role-name>'

    .PARAMETER PrincipalId
    The Entra ID Object ID (GUID) of the user, service principal, or group to assign.

    .PARAMETER PrincipalType
    Whether the principal is a 'User' (covers both users and service principals) or a
    'Group' (Entra ID security group). Defaults to 'User'. This controls which attribute
    condition in the policy JSON receives the principal ID.

    .PARAMETER SkipRoleValidation
    Skips the pre-flight API call that validates the RoleId exists. Useful in batch
    operations where the same validated role ID is reused across many collections.

    .OUTPUTS
    None. The function writes no output on success. Use -Verbose for operational detail.

    .NOTES
    Idempotent: safe to call multiple times with the same arguments.
    Requires an active Az.Accounts session (Connect-AzAccount or a managed identity context)
    with the Purview Collection Administrator role on the target collection.

    .EXAMPLE
    Add-PurviewCollectionRoleMember `
        -AccountName 'contoso-purview' `
        -CollectionName 'abc123' `
        -RoleId 'purviewmetadatarole_builtin_data-curator' `
        -PrincipalId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

    Adds a user or service principal to the Data Curator role on collection 'abc123'
    using the 6-character system name.

    .EXAMPLE
    Add-PurviewCollectionRoleMember `
        -AccountName 'contoso-purview' `
        -CollectionName 'Finance Team' `
        -RoleId 'purviewmetadatarole_builtin_data-curator' `
        -PrincipalId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

    Same assignment using the collection's friendly display name. The system name is
    resolved automatically before the policy is fetched.

    .EXAMPLE
    Add-PurviewCollectionRoleMember `
        -AccountName 'contoso-purview' `
        -CollectionName 'Finance Team' `
        -RoleId 'purviewmetadatarole_builtin_purview-reader' `
        -PrincipalId 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy' `
        -PrincipalType Group

    Assigns an Entra ID security group as Purview Reader. Group membership is evaluated
    transitively by Purview at access time.

    .EXAMPLE
    $assignments = @(
        @{ Collection = 'Finance Team'; Role = 'purviewmetadatarole_builtin_data-curator';    Principal = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' }
        @{ Collection = 'Engineering';  Role = 'purviewmetadatarole_builtin_purview-reader'; Principal = 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy' }
    )
    foreach ($a in $assignments) {
        Add-PurviewCollectionRoleMember `
            -AccountName    'contoso-purview' `
            -CollectionName $a.Collection `
            -RoleId         $a.Role `
            -PrincipalId    $a.Principal `
            -SkipRoleValidation
    }

    Batch IaC pattern. SkipRoleValidation avoids a redundant GET /metadataroles call on
    every iteration when the role IDs are known-good constants.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccountName,

        [Parameter(Mandatory = $true)]
        [string]$CollectionName,

        [Parameter(Mandatory = $true)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $builtInRoles = @(
                'purviewmetadatarole_builtin_collection-administrator'
                'purviewmetadatarole_builtin_data-source-administrator'
                'purviewmetadatarole_builtin_data-curator'
                'purviewmetadatarole_builtin_purview-reader'
                'purviewmetadatarole_builtin_data-share-contributor'
                'purviewmetadatarole_builtin_policy-author'
                'purviewmetadatarole_builtin_workflow-administrator'
                'purviewmetadatarole_builtin_insights-reader'
            )

            $builtInRoles | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$RoleId,

        [Parameter(Mandatory = $true)]
        [string]$PrincipalId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('User', 'Group')]
        [string]$PrincipalType = 'User',

        [Parameter(Mandatory = $false)]
        [switch]$SkipRoleValidation
    )

    # Validate role exists (unless skipped for performance)
    if (-not $SkipRoleValidation) {
        Write-Verbose "Validating role '$RoleId' exists..."
        if (-not (Test-PurviewMetadataRoleExists -AccountName $AccountName -RoleId $RoleId)) {
            $validRoles = (Get-PurviewMetadataRoleIds -AccountName $AccountName) -join "`n  "
            throw "Role '$RoleId' does not exist in account '$AccountName'. Valid roles:`n  $validRoles"
        }
    }

    Write-Verbose "Fetching metadata policy for collection: $CollectionName"
    $Policy = Get-PurviewMetadataPolicy -AccountName $AccountName -CollectionName $CollectionName

    $UpdateResult = Update-PurviewPolicyRoleMemberInternal -Policy $Policy -RoleId $RoleId -PrincipalId $PrincipalId -Action Add -PrincipalType $PrincipalType

    if ($UpdateResult.Updated) {
        Write-Verbose "Policy modified. Pushing update to Purview."

        $PolicyId = $null
        if ($null -ne $UpdateResult.Policy -and $UpdateResult.Policy.PSObject.Properties.Name -contains 'id') {
            $PolicyId = [string]$UpdateResult.Policy.id
        }

        if ([string]::IsNullOrWhiteSpace($PolicyId)) {
            throw "Could not determine Policy ID from the retrieved policy object."
        }

        if ($PSCmdlet.ShouldProcess("$AccountName/$CollectionName", "Add principal '$PrincipalId' ($PrincipalType) to role '$RoleId'")) {
            Update-PurviewMetadataPolicy -AccountName $AccountName -PolicyId $PolicyId -PolicyObject $UpdateResult.Policy
        }
    } else {
        Write-Verbose "No changes needed. Principal '$PrincipalId' already has role '$RoleId'."
    }
}
