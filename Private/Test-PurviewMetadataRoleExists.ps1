function Test-PurviewMetadataRoleExists {
    <#
    .SYNOPSIS
    Validates that a metadata role ID exists in the Purview account.

    .DESCRIPTION
    Queries the available metadata roles and checks if the specified RoleId is valid.
    Returns $true if the role exists, $false otherwise.

    .PARAMETER AccountName
    The name of the Microsoft Purview account.

    .PARAMETER RoleId
    The role ID to validate (e.g., 'purviewmetadatarole_builtin_collection-administrator').
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccountName,

        [Parameter(Mandatory = $true)]
        [string]$RoleId
    )

    try {
        $Roles = Get-PurviewMetadataRole -AccountName $AccountName

        foreach ($role in $Roles) {
            if ($role.id -eq $RoleId -or $role.name -eq $RoleId) {
                return $true
            }
        }

        return $false
    }
    catch {
        throw "Failed to validate role '$RoleId' in account '$AccountName': $($_.Exception.Message)"
    }
}
