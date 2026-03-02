# Releasing PurviewMetadataPolicy

This project supports a **private source repo** and a **public release repo** model.

## Repository roles

- **Private repo**: day-to-day development, internal discussions, tenant integration testing.
- **Public repo**: mirrored release content, public issues/README, PowerShell Gallery publishing.

## Required GitHub configuration

### In private repo

Repository variable:

- `PUBLIC_REPO` = `owner/public-repo-name`

Repository secret:

- `PUBLIC_REPO_PUSH_TOKEN` = fine-grained PAT with `Contents: Read and write` on the public repo

### In public repo

Repository variable:

- `ENABLE_PSGALLERY_PUBLISH` = `true`

Repository secret:

- `PSGALLERY_API_KEY` = API key from PowerShell Gallery

## Workflows

- `.github/workflows/ci.yml`
  - Runs manifest validation, ScriptAnalyzer, and Pester on push/PR.
  - Runs on both PowerShell 7 and Windows PowerShell 5.1.

- `.github/workflows/private-mirror-to-public.yml`
  - Private repo only.
  - Mirrors allowlisted files from `.github/public-sync-include.txt` to the public repo.
  - Triggers on `main` pushes and `v*` tags.

- `.github/workflows/publish-psgallery.yml`
  - Intended to run in public repo only.
  - Publishes on `v*` tags (or manual run), gated by `ENABLE_PSGALLERY_PUBLISH=true`.

## Release flow

1. Complete changes in private repo.
2. Ensure CI is green.
3. Run release helper from repo root:

```powershell
./scripts/Release-Module.ps1 -Bump Patch
```

Or set an explicit version:

```powershell
./scripts/Release-Module.ps1 -Version 0.2.0
```

4. Review generated changes in `PurviewMetadataPolicy.psd1` and `CHANGELOG.md`.
5. Tag release in private repo (`vX.Y.Z`).
6. Mirror workflow syncs to public repo.
7. Tag in public repo triggers PSGallery publish.

## Notes

- Keep `.github/public-sync-include.txt` strict; do not include internal-only files.
- If `Publish-Module` fails due version conflict, increment `ModuleVersion` and retag.
- Keep `ProjectUri` and `LicenseUri` populated in module manifest before first public release.
