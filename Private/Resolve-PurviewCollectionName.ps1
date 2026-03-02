function Resolve-PurviewCollectionName {
    <#
    .SYNOPSIS
    Resolves a Purview collection identifier to its system-assigned 6-character name.

    .DESCRIPTION
    Purview assigns each collection a 6-character alphanumeric system name (e.g. 'abc123')
    that is distinct from its user-visible friendly name (e.g. 'Finance Team'). Most
    Purview data-plane APIs require the system name, not the friendly name.

    This function accepts either form:
    - If the input already matches the 6-character pattern ([a-z0-9]{6}), it is returned
      as-is without making any API call.
    - Otherwise, all collections are fetched from the account/collections API and the
      friendly name is matched case-insensitively. If exactly one match is found, its
      system name is returned. If no match is found, a terminating error is thrown.

    This function is private and is called internally by Get-PurviewMetadataPolicy,
    Add-PurviewCollectionRoleMember, and Remove-PurviewCollectionRoleMember.

    .PARAMETER AccountName
    The name of the Microsoft Purview account.

    .PARAMETER CollectionName
    Either the 6-character system name or the friendly display name of the collection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccountName,

        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    # Already a system name — no API call needed
    if ($CollectionName -match '^[a-z0-9]{6}$') {
        Write-Verbose "CollectionName '$CollectionName' matches system name pattern, using as-is."
        return $CollectionName
    }

    Write-Verbose "Resolving friendly name '$CollectionName' to system collection name..."

    $AllCollections = [System.Collections.Generic.List[object]]::new()
    $NextUri        = 'account/collections'
    $ApiVersion     = '2019-11-01-preview'

    # Page through all collections
    do {
        $Response = Invoke-PurviewRestMethod `
            -AccountName $AccountName `
            -UriSuffix   $NextUri `
            -Method      GET `
            -ApiVersion  $ApiVersion

        if ($Response.value) {
            $AllCollections.AddRange([object[]]$Response.value)
        }

        # The nextLink from the API is a full URL; extract only the path+query after the host
        if (-not [string]::IsNullOrEmpty($Response.nextLink)) {
            $parsed  = [System.Uri]$Response.nextLink
            $NextUri = ($parsed.PathAndQuery).TrimStart('/')
        } else {
            $NextUri = $null
        }
    } while ($NextUri)

    $Match = $AllCollections | Where-Object {
        $_.friendlyName -ieq $CollectionName
    }

    if ($null -eq $Match) {
        $available = ($AllCollections | ForEach-Object { "'$($_.friendlyName)' ($($_.name))" }) -join ', '
        throw "No Purview collection found with friendly name '$CollectionName' in account '$AccountName'. Available collections: $available"
    }

    if (@($Match).Count -gt 1) {
        $dupes = ($Match | ForEach-Object { $_.name }) -join ', '
        throw "Multiple Purview collections matched the friendly name '$CollectionName': $dupes. Use the 6-character system name to disambiguate."
    }

    Write-Verbose "Resolved '$CollectionName' → '$($Match.name)'"
    return $Match.name
}
