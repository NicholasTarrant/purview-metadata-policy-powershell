Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host '== Manifest validation =='
$manifestPath = Join-Path $PSScriptRoot '..\PurviewMetadataPolicy.psd1'
$manifestPath = (Resolve-Path $manifestPath).Path
$manifest = Test-ModuleManifest -Path $manifestPath
Write-Host "Module: $($manifest.Name) Version: $($manifest.Version)"

Write-Host '== ScriptAnalyzer =='
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -ErrorAction Stop
}
Import-Module PSScriptAnalyzer -ErrorAction Stop

$repoRoot = Split-Path $PSScriptRoot -Parent
$analyzeTargets = @(
    (Join-Path $repoRoot 'PurviewMetadataPolicy.psm1')
    (Join-Path $repoRoot 'Public')
    (Join-Path $repoRoot 'Private')
)

$saResults = @()
foreach ($targetPath in $analyzeTargets) {
    $saResults += Invoke-ScriptAnalyzer -Path $targetPath -Recurse -Severity Error,Warning
}
if ($saResults) {
    $saResults | Select-Object RuleName, Severity, ScriptName, Line, Message | Format-Table -AutoSize
}

$errorCount = @($saResults | Where-Object { $_.Severity -eq 'Error' }).Count
if ($errorCount -gt 0) {
    throw "ScriptAnalyzer found $errorCount error(s)."
}

Write-Host '== Pester tests =='
$testsPath = Join-Path $repoRoot 'Tests'
if (Test-Path $testsPath) {
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Install-Module Pester -Scope CurrentUser -Force -ErrorAction Stop
    }

    $invokePester = Get-Command Invoke-Pester -ErrorAction Stop
    $pesterParams = @{}

    if ($invokePester.Parameters.ContainsKey('Path')) {
        $pesterParams.Path = $testsPath
    }
    elseif ($invokePester.Parameters.ContainsKey('Script')) {
        $pesterParams.Script = $testsPath
    }

    if ($invokePester.Parameters.ContainsKey('PassThru')) {
        $pesterParams.PassThru = $true
    }

    if ($invokePester.Parameters.ContainsKey('Output')) {
        $pesterParams.Output = 'Detailed'
    }

    $result = Invoke-Pester @pesterParams

    if ($null -ne $result -and $result.PSObject.Properties.Name -contains 'FailedCount' -and $result.FailedCount -gt 0) {
        throw "Pester reported $($result.FailedCount) failed test(s)."
    }
}
else {
    Write-Host 'No Tests folder found. Skipping Pester.'
}

Write-Host 'Quality checks passed.'
