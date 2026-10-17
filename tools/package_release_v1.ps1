$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$releaseRoot = Join-Path $repoRoot 'release/v1.0.0'
$utf8 = New-Object Text.UTF8Encoding($false)

function Write-GeneratedJson($destination, $value) {
    [IO.File]::WriteAllText($destination, ($value | ConvertTo-Json -Depth 12) + "`n", $utf8)
}

function Copy-VerifiedArtifact($source, $destination) {
    if (Test-Path -LiteralPath $destination) {
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash) {
            throw "Refusing to overwrite an existing different artifact: $destination"
        }
    } else {
        Copy-Item -LiteralPath $source -Destination $destination
    }
}

$scanPath = Join-Path $repoRoot '.tmp/release-secret-scan.json'
$scan = Get-Content -LiteralPath $scanPath -Raw | ConvertFrom-Json
if ($scan.status -ne 'PASS' -or -not $scan.productionProjectSeen -or $scan.findings.Count -ne 0) {
    throw 'A successful source and bundle scan is required before packaging.'
}
# Bind packaging to the precise source and artifact bytes that were scanned.
foreach ($entry in $scan.inventory) {
    $source = [IO.Path]::GetFullPath((Join-Path $repoRoot $entry.file))
    if (-not $source.StartsWith($repoRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Scan inventory path escapes the repository.'
    }
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) {
        throw "Scanned input changed; rescan before packaging: $($entry.file)"
    }
}

foreach ($directory in @('customer', 'rescuer', 'admin', 'docs')) {
    New-Item -ItemType Directory -Path (Join-Path $releaseRoot $directory) -Force | Out-Null
}

$apps = @(
    @{ app = 'customer_app'; folder = 'customer'; package = 'vn.cuuho247.cuu_ho_247' },
    @{ app = 'rescuer_app'; folder = 'rescuer'; package = 'vn.cuuho247.rescuer' }
)
$artifacts = @()
foreach ($app in $apps) {
    $source = Join-Path $repoRoot "frontend/$($app.app)/build/app/outputs/flutter-apk/app-release.apk"
    $relative = "$($app.folder)/$($app.folder)-1.0.0+1-release-unsigned.apk"
    $destination = Join-Path $releaseRoot $relative
    if (-not ($scan.inventory | Where-Object { $_.file -eq "frontend/$($app.app)/build/app/outputs/flutter-apk/app-release.apk" })) {
        throw "Artifact not found in scan inventory: $source"
    }
    Copy-VerifiedArtifact $source $destination
    $artifacts += [ordered]@{
        file = $relative
        bytes = (Get-Item -LiteralPath $destination).Length
        sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        packageId = $app.package
        versionName = '1.0.0'
        versionCode = 1
        signing = 'SIGNING_NOT_CONFIGURED'
        installable = $false
        aab = 'NOT_BUILT_SIGNING_NOT_CONFIGURED'
    }
}

$dist = Join-Path $repoRoot 'admin_web/dist'
$distFiles = @(Get-ChildItem -LiteralPath $dist -Recurse -File -Force)
if (-not $distFiles.Count) { throw 'Admin production bundle is empty.' }
foreach ($file in $distFiles) {
    if ($file.Name -match '^\.|key\.properties|STITCH_DESIGN_REPORT|\.(jks|keystore)$' -or
        $file.Extension -notmatch '^\.(html|js|css|svg|png|jpe?g|webp|ico|woff2?|ttf|otf|json|txt|webmanifest)$') {
        throw "Unexpected file in Admin bundle: $($file.Name)"
    }
    $relative = $file.FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
    if (-not ($scan.inventory | Where-Object { $_.file -eq $relative })) {
        throw "Admin file was not scanned: $relative"
    }
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path $releaseRoot 'admin/admin-v1.0.0-production.zip'
if (-not (Test-Path -LiteralPath $zipPath)) {
    # Windows PowerShell's framework uses backslashes in CreateFromDirectory.
    # Explicit ZIP entry names keep the static bundle portable to Linux hosts.
    $createdZip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $distFiles) {
            $name = $file.FullName.Substring($dist.Length + 1).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $createdZip, $file.FullName, $name, [IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    } finally { $createdZip.Dispose() }
}
# Verify existing/new ZIP against every original bundle file, without extraction.
$zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entries = @($zip.Entries | Where-Object { $_.Name })
    if ($entries.Count -ne $distFiles.Count) { throw 'Admin archive file count differs from dist.' }
    foreach ($file in $distFiles) {
        $name = $file.FullName.Substring($dist.Length + 1).Replace('\', '/')
        $entry = $zip.GetEntry($name)
        if (-not $entry) { throw "Admin archive is missing $name" }
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $digest = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $stream.Dispose(); $sha.Dispose() }
        if ($digest -ne (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash) {
            throw "Existing Admin archive differs from dist: $name"
        }
    }
} finally { $zip.Dispose() }
$artifacts += [ordered]@{
    file = 'admin/admin-v1.0.0-production.zip'
    bytes = (Get-Item -LiteralPath $zipPath).Length
    sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    mode = 'production'
    sourceFiles = $distFiles.Count
    npmPackageVersion = '0.0.0'
}

Write-GeneratedJson (Join-Path $releaseRoot 'docs/SOURCE_AND_BUNDLE_SCAN.json') $scan
$gitHead = & git -C $repoRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot read Git revision.' }
$manifest = [ordered]@{
    release = 'v1.0.0'
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    sourceRevision = ([string]$gitHead).Trim()
    sourceIncludesUncommittedChanges = $true
    flutter = '3.47.5'
    dart = '3.13.4'
    productionProjectRef = 'mqnnzobfzbtolvmatuwr'
    productionConfig = 'PASS_FRONTEND_INPUTS_ONLY'
    signing = 'SIGNING_NOT_CONFIGURED'
    secretScan = 'PASS'
    phoneInstall = 'NOT_RUN_NO_DEVICE_AND_UNSIGNED_APKS'
    readyToTagV1 = $false
    blockers = @(
        'Authentic Android release signing not configured.',
        'Last recorded production preflight: reconciliation migration alignment and authenticated checks incomplete.',
        'Signed APK device installation and smoke tests not performed.'
    )
    validation = [ordered]@{
        customerAnalyze = 'PASS_RETAINED'
        customerTests = 'PASS_613_RETAINED'
        customerReleaseApk = 'PASS_RETAINED'
        rescuerAnalyze = 'PASS_RETAINED'
        rescuerTests = 'PASS_207_RETAINED'
        rescuerReleaseApk = 'PASS_VERBOSE_REBUILD_EXIT_0'
        adminLint = 'PASS_EXIT_0_EXISTING_TEMP_WORK_WARNING'
        adminProductionBuild = 'PASS_EXIT_0'
        adminPlaywright = '83_PRIOR_PASSED_PLUS_1_RETRY_PASSED_OF_84'
    }
    artifacts = $artifacts
}
Write-GeneratedJson (Join-Path $releaseRoot 'docs/MANIFEST.json') $manifest

$allFiles = @(Get-ChildItem -LiteralPath $releaseRoot -Recurse -File -Force | Where-Object { $_.Name -ne 'SHA256SUMS.txt' })
foreach ($file in $allFiles) {
    if ($file.Name -match '^\.(env|git)|key\.properties|STITCH_DESIGN_REPORT|\.(jks|keystore)$' -or
        $file.FullName -match '[\\/](\.payment-sevqr-work|test-results|node_modules)[\\/]') {
        throw "Forbidden packaged file: $($file.Name)"
    }
}
$sums = @($allFiles | Sort-Object FullName | ForEach-Object {
    $name = $_.FullName.Substring($releaseRoot.Length + 1).Replace('\', '/')
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $name
})
[IO.File]::WriteAllText((Join-Path $releaseRoot 'SHA256SUMS.txt'), ($sums -join "`n") + "`n", $utf8)
Write-Output "Packaged $($artifacts.Count) build artifacts; checksums cover $($allFiles.Count) files. Android APKs remain UNSIGNED."
