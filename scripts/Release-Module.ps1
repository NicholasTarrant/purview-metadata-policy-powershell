param(
    [Parameter(Mandatory = $false)]
    [version]$Version,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Major', 'Minor', 'Patch')]
    [string]$Bump = 'Patch'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $repoRoot 'PurviewMetadataPolicy.psd1'
$changelogPath = Join-Path $repoRoot 'CHANGELOG.md'

if (-not (Test-Path $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

$manifest = Import-PowerShellDataFile -Path $manifestPath
$currentVersion = [version]$manifest.ModuleVersion

if ($null -eq $Version) {
    switch ($Bump) {
        'Major' { $Version = [version]::new($currentVersion.Major + 1, 0, 0) }
        'Minor' { $Version = [version]::new($currentVersion.Major, $currentVersion.Minor + 1, 0) }
        'Patch' { $Version = [version]::new($currentVersion.Major, $currentVersion.Minor, $currentVersion.Build + 1) }
    }
}

$newVersion = $Version.ToString()
$tagName = "v$newVersion"
$dateText = (Get-Date).ToString('yyyy-MM-dd')

$manifestRaw = Get-Content -Path $manifestPath -Raw -Encoding UTF8
$manifestUpdated = $manifestRaw -replace "ModuleVersion\s*=\s*'[^']+'", "ModuleVersion = '$newVersion'"
if ($manifestUpdated -eq $manifestRaw) {
    throw 'ModuleVersion was not updated. Check manifest format.'
}
Set-Content -Path $manifestPath -Value $manifestUpdated -Encoding UTF8

if (Test-Path $changelogPath) {
    $changelogRaw = Get-Content -Path $changelogPath -Raw -Encoding UTF8
    if ($changelogRaw -match "## \[Unreleased\]") {
        $releaseHeader = "## [$newVersion] - $dateText"
        if ($changelogRaw -notmatch [regex]::Escape($releaseHeader)) {
            $insert = "## [Unreleased]`r`n`r`n## [$newVersion] - $dateText"
            $changelogUpdated = $changelogRaw -replace "## \[Unreleased\]", [regex]::Escape($insert).Replace('\\r\\n', "`r`n")
            if ($changelogUpdated -eq $changelogRaw) {
                $changelogUpdated = $changelogRaw -replace "## \[Unreleased\]", $insert
            }
            Set-Content -Path $changelogPath -Value $changelogUpdated -Encoding UTF8
        }
    }
}

Write-Host "Updated manifest version: $($currentVersion.ToString()) -> $newVersion"
Write-Host "Tag to create: $tagName"
Write-Host ''
Write-Host 'Next commands:'
Write-Host 'git add PurviewMetadataPolicy.psd1 CHANGELOG.md'
Write-Host ('git commit -m "release: {0}"' -f $newVersion)
Write-Host ("git tag {0}" -f $tagName)
Write-Host 'git push origin main --tags'
