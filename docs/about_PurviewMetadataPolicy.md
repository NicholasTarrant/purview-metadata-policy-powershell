# about_PurviewMetadataPolicy

## SHORT DESCRIPTION
Explains the concepts behind Microsoft Purview metadata policies and describes how
this module manages role assignments against the Purview data-plane API.

## LONG DESCRIPTION

### What is a metadata policy?

In Microsoft Purview, every collection has exactly one **metadata policy** — a JSON
document that governs who can access that collection and in what capacity. When you
assign a user to the Data Curator role via the Purview portal, the portal is updating
that collection's metadata policy behind the scenes.

The PurviewMetadataPolicy module interacts directly with the policy documents via the
`/policystore/` data-plane API, enabling the same assignments to be made programmatically
from scripts, CI/CD pipelines, and IaC tooling.

### Policy structure

A metadata policy contains two key arrays:

**attributeRules** — one entry per role per collection. Each entry has a `dnfCondition`
(Disjunctive Normal Form) that encodes who holds the role. The first OR-clause in that
structure is where explicit principal assignments live; the second OR-clause encodes
permissions inherited from a parent collection and is managed entirely by Purview.

**decisionRules** — bind the attribute rules together to form an access decision.
For most automation work these can be treated as opaque.

### Principal types

Two attribute names exist for principal assignment within a rule's dnfCondition:

```
principal.microsoft.id        — users and service principals (Object IDs)
principal.microsoft.groups.id — Entra ID security groups (transitive membership)
```

Use `-PrincipalType User` (the default) for users and service principals, and
`-PrincipalType Group` for Entra ID security groups. The module routes the principal
ID to the correct attribute condition based on this value. If you assign a group GUID
under the `User` type, Purview will not resolve group membership correctly.

### Collection names

Purview assigns each collection a **6-character alphanumeric system name** (e.g. `abc123`)
at creation time. This system name is what the `/policystore/` API accepts, and it is
distinct from the human-readable **friendly name** visible in the portal (e.g. `Finance Team`).

This module accepts either form for every `-CollectionName` parameter:

- A value matching `[a-z0-9]{6}` is treated as a system name and used as-is.
- Any other value triggers a collection lookup against `/account/collections` to resolve
  the friendly name to its system name.

The root collection is a special case: its system name is always identical to the name
of the Purview account itself.

### Idempotency

`Add-PurviewCollectionRoleMember` and `Remove-PurviewCollectionRoleMember` are both
idempotent operations:

- Adding a principal that already holds the role results in no API write and no error.
- Removing a principal that does not hold the role results in no API write and no error.

This makes the functions safe to call unconditionally in declarative IaC pipelines where
the desired state must be enforced without knowledge of the current state.

### Authentication

This module relies on `Az.Accounts` for authentication. Before calling any function,
establish a session:

```powershell
# Interactive (local development)
Connect-AzAccount

# Service principal (CI/CD)
Connect-AzAccount -ServicePrincipal -TenantId $tenantId -Credential $cred

# Azure DevOps — use the AzurePowerShell@5 task; no Connect-AzAccount needed
```

The module calls `Get-AzAccessToken -ResourceUrl "https://purview.azure.net"` on every
request. Token caching is handled by Az.Accounts.

### API versioning

| API surface | Version used |
|---|---|
| `/policystore/` (metadata policy, roles) | `2021-07-01` |
| `/account/collections/` (name resolution) | `2019-11-01-preview` |

These are fixed in the module. The collections API version is used only for the internal
name resolution call and is not exposed publicly.

### Required permissions

The calling identity must hold the **Collection Administrator** role on the collection
being modified. This is a Purview data-plane role, not an Azure RBAC role — it must be
assigned through Purview itself (or via this module).

To bootstrap access to the root collection for a service principal:
1. Ensure the identity has at minimum the `Reader` Azure RBAC role on the Purview resource
2. Assign the Collection Administrator role on the root collection via the Azure portal or
   the Purview governance portal
3. From that point, the service principal can use this module to manage all other assignments

## EXAMPLES

### Enumerate current members of a role

```powershell
$policy = Get-PurviewMetadataPolicy -AccountName 'contoso-purview' -CollectionName 'Finance Team'
$rule   = $policy.properties.attributeRules | Where-Object { $_.id -like '*data-curator*' }
$cond   = $rule.dnfCondition[0] | Where-Object { $_.attributeName -eq 'principal.microsoft.id' }
$cond.attributeValueIncludedIn
```

### Audit all policies for a specific principal

```powershell
$principalId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

Get-PurviewMetadataPolicy -AccountName 'contoso-purview' | ForEach-Object {
    $policyName = $_.name
    $_.properties.attributeRules | ForEach-Object {
        $roleId = $_.id
        $_.dnfCondition | ForEach-Object {
            $_ | Where-Object {
                $_.attributeName -in 'principal.microsoft.id','principal.microsoft.groups.id' -and
                $principalId -in $_.attributeValueIncludedIn
            } | ForEach-Object {
                [PSCustomObject]@{ Policy = $policyName; Role = $roleId; AttributeName = $_.attributeName }
            }
        }
    }
}
```

## NOTE

This module only covers the Purview metadata policy data-plane surface. It does not
manage collections, scanning, data catalog entities, or glossary terms. Those surfaces
would require separate modules against different base URLs and API versions.

## SEE ALSO

- `Get-Help Get-PurviewMetadataRole`
- `Get-Help Get-PurviewMetadataPolicy`
- `Get-Help Add-PurviewCollectionRoleMember`
- `Get-Help Remove-PurviewCollectionRoleMember`
- `Get-Help Update-PurviewMetadataPolicy`
- [Purview Metadata Policy REST API](https://learn.microsoft.com/en-us/rest/api/purview/metadatapolicydataplane/metadata-policy)
- [Purview collection-level RBAC](https://learn.microsoft.com/en-us/azure/purview/catalog-permissions)
- [Tutorial: Manage role assignments via REST](https://learn.microsoft.com/purview/legacy/tutorial-metadata-policy-collections-apis)

## KEYWORDS

- Purview
- MetadataPolicy
- RBAC
- IaC
- Collections
- RoleAssignment
