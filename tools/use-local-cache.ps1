# Run from repository root when the machine's TEMP/Pub cache is not writable.
& {
$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workRoot = Join-Path $repoRoot 'tools/.work'
$tempPath = Join-Path $workRoot 'temp'
$pubPath = Join-Path $workRoot 'pub-cache'
foreach ($path in @($tempPath, $pubPath)) {
    $absolute = [System.IO.Path]::GetFullPath($path)
    if (-not $absolute.StartsWith($repoRoot.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Cache path must stay inside this repository.'
    }
    New-Item -ItemType Directory -Path $absolute -Force | Out-Null
}
$env:TEMP = $tempPath
$env:TMP = $tempPath
$env:PUB_CACHE = $pubPath
Write-Output 'TEMP/TMP/PUB_CACHE set to ignored tools/.work directories for this PowerShell session.'
}
