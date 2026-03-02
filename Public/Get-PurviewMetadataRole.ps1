function Get-PurviewMetadataRole {
    <#
    .SYNOPSIS
    Lists the built-in metadata roles available in a Microsoft Purview account.

    .DESCRIPTION
    Queries the /policystore/metadataroles endpoint and returns all metadata role
    objects for the account. Purview metadata roles are built-in and read-only —
    they cannot be created, renamed, or deleted via the API.

    Standard built-in roles:

    Role ID                                                        Description
    -------                                                        -----------
    purviewmetadatarole_builtin_collection-administrator           Full admin access to the collection
    purviewmetadatarole_builtin_data-source-administrator          Register data sources, trigger scans
    purviewmetadatarole_builtin_data-curator                       Full access to data and metadata
    purviewmetadatarole_builtin_purview-reader                     Read-only access
    purviewmetadatarole_builtin_data-share-contributor             Data share contributor

    .PARAMETER AccountName
    The name of the Microsoft Purview account (the subdomain portion of
    https://<AccountName>.purview.azure.com).

    .OUTPUTS
    PSCustomObject[]. An array of role objects, each with 'id', 'name', 'friendlyName',
    and 'cnfCondition' properties.

    .NOTES
    The set of built-in roles is consistent across accounts, but querying the account
    directly is safe practice and accounts for any future additions by Microsoft.

    .EXAMPLE
    Get-PurviewMetadataRole -AccountName 'contoso-purview'

    Returns all metadata role objects for the account.

    .EXAMPLE
    (Get-PurviewMetadataRole -AccountName 'contoso-purview').id

    Returns just the role ID strings — useful for discovering valid values to pass
    as -RoleId to Add-PurviewCollectionRoleMember.

    .EXAMPLE
    Get-PurviewMetadataRole -AccountName 'contoso-purview' |
        Select-Object id, friendlyName |
        Format-Table -AutoSize

    Displays a formatted table of role IDs and their human-readable names.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccountName
    )

    $UriSuffix = "/policystore/metadataroles"
    $Response = Invoke-PurviewRestMethod -AccountName $AccountName -UriSuffix $UriSuffix -Method GET

    return $Response.values
}
