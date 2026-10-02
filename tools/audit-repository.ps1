# Read-only repository audit; no source deletion, staging, or remote calls.
$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location $repoRoot
try {
    & git -c "safe.directory=$repoRoot" status --short
    & git -c "safe.directory=$repoRoot" clean -ndX
    $paths = @(& rg --files --hidden --no-ignore -g '!.git/**')
    $large = foreach ($relative in $paths) {
        $item = Get-Item -LiteralPath (Join-Path $repoRoot $relative) -ErrorAction SilentlyContinue
        if ($item -and $item.Length -gt 10MB) {
            [pscustomobject]@{ Path = $relative; Bytes = $item.Length }
        }
    }
    $large | Sort-Object Bytes -Descending | Format-Table -AutoSize

    $tracked = @(& git -c "safe.directory=$repoRoot" ls-files)
    $candidates = @($tracked) + @(& git -c "safe.directory=$repoRoot" ls-files --others --exclude-standard)
    $suspect = @()
    foreach ($relative in ($candidates | Sort-Object -Unique)) {
        if ($relative -match '(^|/)(supabase\.dev\.json|backend-tests\.dev\.json|key\.properties)$|\.(jks|keystore)$|(^|/)\.env($|\.)') {
            $suspect += [pscustomobject]@{ Path = $relative; Reason = 'Private configuration/signing path' }
            continue
        }
        if ($relative -notmatch '\.(dart|json|yaml|yml|md|ps1|mjs|js|toml|properties|xml|sql)$') { continue }
        $full = Join-Path $repoRoot $relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        $content = [System.IO.File]::ReadAllText($full)
        if ($content -cmatch 'sb_(secret|publishable)_[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----') {
            $suspect += [pscustomobject]@{ Path = $relative; Reason = 'Credential-like value; inspect locally without printing it' }
        }
    }
    foreach ($private in @(
        'frontend/customer_app/config/supabase.dev.json',
        'frontend/customer_app/config/backend-tests.dev.json',
        'frontend/customer_app/android/local.properties'
    )) {
        & git -c "safe.directory=$repoRoot" check-ignore -q -- $private
        if ($LASTEXITCODE -ne 0) { throw "Private path is not ignored: $private" }
    }
    if ($suspect.Count) {
        $suspect | Format-Table -AutoSize
        throw 'Potential credentials found in tracked or versionable files. Values omitted.'
    }
    Write-Output ("Audit passed: {0} files inventoried; {1} tracked files; private paths ignored." -f $paths.Count, $tracked.Count)
} finally {
    Pop-Location
}

