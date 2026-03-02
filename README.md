# PurviewMetadataPolicy

A PowerShell module for managing Microsoft Purview metadata policy role assignments via the Purview data-plane REST API. Designed for Infrastructure-as-Code (IaC) pipelines where collection role assignments must be applied reliably and repeatably.

## Scope

This module covers the `/policystore/` API surface only:

- Listing built-in metadata roles
- Reading metadata policies (all, by collection, by ID)
- Adding and removing principals (users, service principals, groups) from collection roles
- Writing updated policies back to the API

It does not cover collection management, scanning, data catalog, or glossary APIs.

## Prerequisites

- **PowerShell** 5.1 or later (Windows PowerShell or PowerShell 7+)
- **Az.Accounts** 2.0.0 or later — provides `Get-AzAccessToken`
- An authenticated Azure session:
  - Local: `Connect-AzAccount`
  - Azure DevOps: `AzurePowerShell@5` task (managed identity or service principal)
  - Other CI: service principal via `Connect-AzAccount -ServicePrincipal`
- The calling identity must hold the **Collection Administrator** role on the target Purview collection

## Installation

```powershell
Install-Module -Name PurviewMetadataPolicy
```

Or for a specific version:

```powershell
Install-Module -Name PurviewMetadataPolicy -RequiredVersion 0.1.0
```

## Quick Start

### Add a user to a role

```powershell
Add-PurviewCollectionRoleMember `
    -AccountName  'contoso-purview' `
    -CollectionName 'Finance Team' `
    -RoleId       'purviewmetadatarole_builtin_data-curator' `
    -PrincipalId  'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```

### Add a group to a role

```powershell
Add-PurviewCollectionRoleMember `
    -AccountName    'contoso-purview' `
    -CollectionName 'Finance Team' `
    -RoleId         'purviewmetadatarole_builtin_purview-reader' `
    -PrincipalId    'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy' `
    -PrincipalType  Group
```

### Remove a principal from a role

```powershell
Remove-PurviewCollectionRoleMember `
    -AccountName    'contoso-purview' `
    -CollectionName 'Finance Team' `
    -RoleId         'purviewmetadatarole_builtin_data-curator' `
    -PrincipalId    'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```

### Discover available roles

```powershell
Get-PurviewMetadataRole -AccountName 'contoso-purview' |
    Select-Object id, friendlyName |
    Format-Table -AutoSize
```

### Batch IaC assignment

```powershell
$assignments = @(
    @{ Collection = 'Finance Team'; Role = 'purviewmetadatarole_builtin_data-curator';          Principal = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' }
    @{ Collection = 'Engineering';  Role = 'purviewmetadatarole_builtin_purview-reader';        Principal = 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy' }
    @{ Collection = 'Engineering';  Role = 'purviewmetadatarole_builtin_data-source-administrator'; Principal = 'zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz' }
)

foreach ($a in $assignments) {
    Add-PurviewCollectionRoleMember `
        -AccountName      'contoso-purview' `
        -CollectionName   $a.Collection `
        -RoleId           $a.Role `
        -PrincipalId      $a.Principal `
        -SkipRoleValidation  # skip redundant GET /metadataroles on every iteration
}
```

## Collection Names

Purview assigns every collection a **6-character alphanumeric system name** (e.g. `abc123`) that differs from its user-visible **friendly name** (e.g. `Finance Team`). This module accepts either form wherever a `-CollectionName` parameter appears.

- Passing the 6-character system name skips a collection-lookup API call — use this in performance-sensitive loops
- Passing a friendly name triggers a single `GET /account/collections` call to resolve it; the resolved ID is then used for all subsequent calls in that invocation

If you pass a friendly name and no collection matches, or two collections share the same name, a terminating error is thrown with actionable detail.

## Built-in Role IDs

| Role ID | Description |
|---------|-------------|
| `purviewmetadatarole_builtin_collection-administrator` | Full admin access to the collection |
| `purviewmetadatarole_builtin_data-source-administrator` | Register data sources, trigger scans |
| `purviewmetadatarole_builtin_data-curator` | Full access to data and metadata |
| `purviewmetadatarole_builtin_purview-reader` | Read-only access |
| `purviewmetadatarole_builtin_data-share-contributor` | Data share contributor |

## Idempotency

`Add-PurviewCollectionRoleMember` and `Remove-PurviewCollectionRoleMember` are both idempotent:

- Adding a principal that already holds the role → no API write, silent success
- Removing a principal that does not hold the role → no API write, silent success

Both operations complete without error. Run with `-Verbose` to see whether a write actually occurred.

## Commands

| Command | Description |
|---------|-------------|
| `Get-PurviewMetadataRole` | List all built-in metadata roles |
| `Get-PurviewMetadataPolicy` | Get policies (all, by collection, by ID) |
| `Update-PurviewMetadataPolicy` | Write an updated policy object back to the API |
| `Add-PurviewCollectionRoleMember` | Add a principal to a collection role |
| `Remove-PurviewCollectionRoleMember` | Remove a principal from a collection role |

Full documentation: `Get-Help <CommandName> -Full`

## Further Reading

- [Purview Metadata Policy REST API](https://learn.microsoft.com/en-us/rest/api/purview/metadatapolicydataplane/metadata-policy)
- [Tutorial: Manage collection role assignments via REST](https://learn.microsoft.com/purview/legacy/tutorial-metadata-policy-collections-apis)
- [Purview RBAC overview](https://learn.microsoft.com/en-us/azure/purview/catalog-permissions)

## Release & Publishing

This project supports a private-source/public-release workflow with PowerShell Gallery publishing via GitHub Actions.

- See [docs/RELEASING.md](docs/RELEASING.md) for required secrets/variables and the release flow.
- CI quality checks are defined in `.github/workflows/ci.yml`.
- Public release publishing is defined in `.github/workflows/publish-psgallery.yml`.
