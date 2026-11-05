# relay-init.ps1
# Copies the Relay kit files into the current project folder.
# Never overwrites an existing file. Safe to run more than once.
# Usage (inside the project folder):
#   powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\relay-kit\relay-init.ps1"

$ErrorActionPreference = 'Continue'

$kitDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $kitDir 'templates/project'
$dest = (Get-Location).Path

if (-not (Test-Path $src)) {
    Write-Host "ERROR: template folder not found: $src"
    exit 2
}

# Make sure this is a git repo
& git rev-parse --show-toplevel 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "No git repo here. Running: git init"
    & git init | Out-Null
}

$created = @()
$skipped = @()

$files = Get-ChildItem -Path $src -Recurse -File
foreach ($f in $files) {
    $rel = $f.FullName.Substring($src.Length).TrimStart('\', '/')
    $target = Join-Path $dest $rel
    $targetDir = Split-Path -Parent $target
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    if (Test-Path $target) {
        $skipped += $rel
    } else {
        Copy-Item -Path $f.FullName -Destination $target
        $created += $rel
    }
}

Write-Host ""
Write-Host "Relay kit in: $dest"
Write-Host "Created ($($created.Count)):"
foreach ($c in $created) { Write-Host "  + $c" }
if ($skipped.Count -gt 0) {
    Write-Host "Already existed, NOT changed ($($skipped.Count)):"
    foreach ($s in $skipped) { Write-Host "  = $s" }
    Write-Host "Note: if an existing QWEN.md or AGENTS.md has other content, add this line to it:"
    Write-Host "  Read and follow relay/WORKER.md before doing anything."
}
exit 0
