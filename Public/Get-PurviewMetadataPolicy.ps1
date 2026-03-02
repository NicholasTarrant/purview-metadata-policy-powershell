function Get-PurviewMetadataPolicy {
    <#
    .SYNOPSIS
    Retrieves metadata policies from a Microsoft Purview account.

    .DESCRIPTION
    Returns Purview metadata policy objects from the /policystore API. Supports three
    retrieval modes via parameter sets:

    - ListAll (default): returns all policies in the account as an array
    - ByCollectionName: returns the single policy governing a named collection
    - ByPolicyId: returns a policy by its GUID

    The returned policy object is the live document used by Add-PurviewCollectionRoleMember
    and Remove-PurviewCollectionRoleMember. It can also be modified directly and pushed
    back via Update-PurviewMetadataPolicy for advanced scenarios.

    .PARAMETER AccountName
    The name of the Microsoft Purview account (the subdomain portion of
    https://<AccountName>.purview.azure.com).

    .PARAMETER CollectionName
    The collection whose metadata policy to retrieve. Accepts either the 6-character
    system name (e.g. 'abc123') or the friendly display name (e.g. 'Finance Team').
    Friendly names are resolved automatically via the account/collections API.

    .PARAMETER PolicyId
    The GUID of the metadata policy to retrieve. Obtain policy GUIDs from the ListAll
    result or from the Purview portal.

    .OUTPUTS
    PSCustomObject. A single policy object (ByCollectionName / ByPolicyId) or an array
    of policy objects (ListAll). The policy object contains 'id', 'name', 'version',
    and 'properties' (which holds 'attributeRules' and 'decisionRules').

    .NOTES
    Each collection has exactly one metadata policy. The policy ID is stable — it does
    not change when the policy is updated.

    .EXAMPLE
    Get-PurviewMetadataPolicy -AccountName 'contoso-purview'

    Returns all metadata policies in the account. Useful for auditing current role
    assignments across all collections.

    .EXAMPLE
    Get-PurviewMetadataPolicy -AccountName 'contoso-purview' -CollectionName 'Finance Team'

    Returns the metadata policy for the 'Finance Team' collection. The friendly name is
    resolved to the system name before the API call is made.

    .EXAMPLE
    Get-PurviewMetadataPolicy -AccountName 'contoso-purview' -CollectionName 'abc123'

    Returns the metadata policy using the 6-character system name directly, skipping
    the collection name resolution API call.

    .EXAMPLE
    Get-PurviewMetadataPolicy -AccountName 'contoso-purview' -PolicyId 'c6639bb2-9c41-4be0-912b-775750e725de'

    Returns a specific policy by its GUID.

    .EXAMPLE
    $policy = Get-PurviewMetadataPolicy -AccountName 'contoso-purview' -CollectionName 'Finance Team'
    $policy.properties.attributeRules | Where-Object { $_.id -like '*data-curator*' }

    Retrieves a policy and inspects the attribute rules to see current Data Curator
    role members directly.
    #>
    [CmdletBinding(DefaultParameterSetName='ListAll')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ListAll')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByPolicyId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionName')]
        [string]$AccountName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPolicyId')]
        [string]$PolicyId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionName')]
        [string]$CollectionName
    )

    switch ($PSCmdlet.ParameterSetName) {
        'ListAll' {
            $UriSuffix = "/policystore/metadataPolicies"
        }
        'ByPolicyId' {
            $UriSuffix = "/policystore/metadataPolicies/$PolicyId"
        }
        'ByCollectionName' {
            $CollectionName = Resolve-PurviewCollectionName -AccountName $AccountName -CollectionName $CollectionName
            $UriSuffix = "/policystore/collections/$CollectionName/metadataPolicy"
        }
    }

    $Response = Invoke-PurviewRestMethod -AccountName $AccountName -UriSuffix $UriSuffix -Method GET
    
    if ($PSCmdlet.ParameterSetName -eq 'ListAll') {
        return $Response.values
    } else {
        return $Response
    }
}
