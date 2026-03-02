# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- GitHub Actions CI workflow for manifest validation, ScriptAnalyzer, and Pester on PowerShell 7 and Windows PowerShell 5.1
- Private-to-public repository mirror workflow with allowlisted file sync
- PSGallery publish workflow gated by repository variable and API key secret
- Maintainer release guide at `docs/RELEASING.md`

### Fixed
- Restored true PowerShell 5.1 compatibility by replacing PowerShell 7-only null-conditional/null-coalescing operators in REST error handling
- Hardened role rule targeting to use exact role identity matching instead of wildcard substring matching
- Improved role validation behavior to surface underlying API/authentication failures instead of reporting false role-missing results
- Added `SupportsShouldProcess` (`-WhatIf`/`-Confirm`) support for all mutating commands
- Aligned module manifest version with documented release version (`0.1.0`)

---

## [0.1.0] - 2026-03-02

### Added
- `Get-PurviewMetadataRole` — list all built-in metadata roles for a Purview account
- `Get-PurviewMetadataPolicy` — retrieve metadata policies by account (all), collection name, or policy GUID
- `Update-PurviewMetadataPolicy` — write a modified policy object back to the API via PUT
- `Add-PurviewCollectionRoleMember` — add a user, service principal, or Entra ID group to a collection role
  - Accepts either 6-character system name or friendly display name for `-CollectionName`
  - Idempotent: no write if the principal already holds the role
  - `-SkipRoleValidation` switch for performance in batch loops
- `Remove-PurviewCollectionRoleMember` — remove a principal from a collection role
  - Same collection name flexibility and idempotency as `Add-PurviewCollectionRoleMember`
- Private `Invoke-PurviewRestMethod` — generic Purview data-plane REST wrapper with structured error messages
- Private `Resolve-PurviewCollectionName` — transparent friendly name to 6-char system name resolution with pagination support
- Private `Test-PurviewMetadataRoleExists` — pre-flight role ID validation
- Private `Get-PurviewMetadataRoleIds` — returns role IDs as strings for error message construction
- Private `Update-PurviewPolicyRoleMemberInternal` — core dnfCondition mutation logic (add/remove)
- Private `Find-PrincipalConditionEntry` — locates the principal condition block within a policy's attributeRules
