function Get-PurviewMetadataRoleIds {
    <#
    .SYNOPSIS
    Returns the list of valid metadata role IDs for a Purview account.

    .DESCRIPTION
    Queries the metadata roles endpoint and returns the role IDs as a flat string array.
    Used internally to build human-readable error messages when role validation fails.

    .PARAMETER AccountName
    The name of the Microsoft Purview account.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccountName
    )

    $Roles = Get-PurviewMetadataRole -AccountName $AccountName
    return $Roles | ForEach-Object { $_.id }
}
