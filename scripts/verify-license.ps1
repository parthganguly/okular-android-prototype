[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $root
try {
    $required = @(
        "ATTRIBUTION.md",
        "LICENSES/GPL-2.0-or-later.txt",
        "LICENSES/GPL-3.0-or-later.txt",
        "LICENSES/LGPL-2.0-or-later.txt"
    )
    foreach ($path in $required) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Fail "Required attribution/license file is missing: $path"
        }
    }

    $attribution = Get-Content -LiteralPath "ATTRIBUTION.md" -Raw
    foreach ($term in @("Parthicle Reader", "Okular", "KDE", "GPL")) {
        if ($attribution -notmatch [regex]::Escape($term)) {
            Fail "ATTRIBUTION.md is missing required term: $term"
        }
    }

    $deleted = @(
        git diff --diff-filter=D --name-only -- "LICENSES" "COPYING*" "LICENSE*" "ATTRIBUTION.md" ".reuse" "REUSE.toml"
        git diff --cached --diff-filter=D --name-only -- "LICENSES" "COPYING*" "LICENSE*" "ATTRIBUTION.md" ".reuse" "REUSE.toml"
    ) | Where-Object { $_ }
    if ($LASTEXITCODE -ne 0) {
        Fail "git diff failed while checking protected files."
    }
    if ($deleted.Count -gt 0) {
        Fail "Protected licensing files are deleted: $($deleted -join ', ')"
    }

    $licenseCount = @(git ls-files "LICENSES/*").Count
    if ($LASTEXITCODE -ne 0 -or $licenseCount -lt 1) {
        Fail "No tracked LICENSES entries were found."
    }

    $removedSpdx = @(
        git diff -U0 -- . ':!docs/**' ':!*.md'
        git diff --cached -U0 -- . ':!docs/**' ':!*.md'
    ) | Where-Object { $_ -match '^-[^-].*SPDX-(FileCopyrightText|License-Identifier):' }
    if ($removedSpdx.Count -gt 0) {
        Fail "SPDX metadata removal detected. Review the diff with explicit approval."
    }

    Write-Host "License files: $licenseCount tracked entries"
    Write-Host "Attribution: Okular/KDE/GPL terms present"
    Write-Host "Protected deletions: none"
    Write-Host "SPDX removals in current diff: none"

    $reuse = Get-Command reuse -ErrorAction SilentlyContinue
    if ($reuse) {
        Write-Host "Optional reuse-tool: installed (run 'reuse lint' for the full REUSE audit)"
    } else {
        Write-Host "Optional reuse-tool: not installed; full REUSE audit not run"
    }
} finally {
    Pop-Location
}
