# PurviewMetadataPolicy.psm1 - Root module script

$publicScripts  = Get-ChildItem -Path "$PSScriptRoot\Public" -Filter "*.ps1" -Recurse
$privateScripts = Get-ChildItem -Path "$PSScriptRoot\Private" -Filter "*.ps1" -Recurse

# Load private functions
foreach ($script in $privateScripts) {
    if (Test-Path $script.FullName) {
        . $script.FullName
    }
}

# Load public functions and explicitly export them
foreach ($script in $publicScripts) {
    if (Test-Path $script.FullName) {
        . $script.FullName
        Export-ModuleMember -Function $script.BaseName
    }
}
