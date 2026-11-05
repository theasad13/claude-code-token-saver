# INSTALL.ps1 - installs the Relay Mode kit into your Claude folder (~/.claude).
# Run from this folder:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\INSTALL.ps1
# Existing files are backed up to ~/.claude/backups/relay-kit-<time>/ before they are replaced.
# (Backups are NOT put next to the files, so templates stay clean.) Nothing is deleted.

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcRoot = Join-Path $here 'claude'
$claudeDir = Join-Path $HOME '.claude'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path (Join-Path $claudeDir 'backups') "relay-kit-$stamp"
function Backup-File([string]$path, [string]$rel) {
    $dest = Join-Path $backupDir $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    Copy-Item $path $dest
}

if (-not (Test-Path $srcRoot)) { Write-Host "ERROR: 'claude' folder not found next to INSTALL.ps1"; exit 2 }
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }

$new = 0; $same = 0; $replaced = 0
foreach ($part in @('agents', 'skills', 'relay-kit')) {
    $src = Join-Path $srcRoot $part
    $files = Get-ChildItem -Path $src -Recurse -File
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($srcRoot.Length).TrimStart('\', '/')
        $target = Join-Path $claudeDir $rel
        $dir = Split-Path -Parent $target
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if (Test-Path $target) {
            $a = (Get-FileHash $f.FullName).Hash
            $b = (Get-FileHash $target).Hash
            if ($a -eq $b) { $same++; continue }
            Backup-File $target $rel
            Copy-Item $f.FullName $target -Force
            Write-Host "  replaced (backup kept): $rel"
            $replaced++
        } else {
            Copy-Item $f.FullName $target
            Write-Host "  added: $rel"
            $new++
        }
    }
}

# Guides go next to the kit
foreach ($g in @('README-URDU.md', 'SPEC-PROMPT-ChatGPT-Gemini.md')) {
    $gs = Join-Path $here $g
    if (Test-Path $gs) { Copy-Item $gs (Join-Path $claudeDir "relay-kit\$g") -Force }
}

# Add the Relay section to ~/.claude/CLAUDE.md once
$claudeMd = Join-Path $claudeDir 'CLAUDE.md'
$section = (Get-Content (Join-Path $srcRoot 'CLAUDE-relay-section.md') -Raw -Encoding UTF8).Trim() + "`r`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$existing = ''
if (Test-Path $claudeMd) { $existing = Get-Content $claudeMd -Raw -Encoding UTF8 }
if ($existing -and $existing.Contains('relay-mode:start')) {
    # Replace only the marked block; text before and after it stays exactly as it is.
    $pattern = '(?s)<!-- relay-mode:start -->.*?<!-- relay-mode:end -->'
    $block = $section.Trim()
    $updated = [regex]::Replace($existing, $pattern, { param($m) $block })
    if ($updated -ne $existing) {
        Backup-File $claudeMd 'CLAUDE.md'
        [System.IO.File]::WriteAllText($claudeMd, $updated.TrimStart([char]0xFEFF), $utf8NoBom)
        Write-Host "  CLAUDE.md: Relay section updated (backup kept)"
    } else {
        Write-Host "  CLAUDE.md: Relay section already up to date"
    }
} else {
    if (Test-Path $claudeMd) { Backup-File $claudeMd 'CLAUDE.md' }
    $new2 = $section
    if ($existing) { $new2 = $existing.TrimEnd() + "`r`n`r`n" + $section }
    [System.IO.File]::WriteAllText($claudeMd, $new2.TrimStart([char]0xFEFF), $utf8NoBom)
    Write-Host "  CLAUDE.md: Relay section added"
}

# Allow ONLY the Codex worker command in ~/.claude/settings.json, so relay-run codex does not
# ask permission for every task. Nothing broader is allowed. If settings.json cannot be read
# safely, it is left untouched and the rule is printed for manual adding.
$settingsFile = Join-Path $claudeDir 'settings.json'
$workerCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude/relay-kit/codex-worker.ps1" -TaskId *'
$rules = @("Bash($workerCmd)", "PowerShell($workerCmd)")
$settingsText = ''
if (Test-Path $settingsFile) { $settingsText = [System.IO.File]::ReadAllText($settingsFile) }
$missing = @($rules | Where-Object { -not $settingsText.Contains($_.Replace('"', '\"')) })
if ($missing.Count -eq 0) {
    Write-Host "  settings.json: Codex worker permission already present"
} else {
    $settings = $null
    $ok = $true
    if ($settingsText.Trim()) {
        try { $settings = $settingsText | ConvertFrom-Json -ErrorAction Stop } catch { $ok = $false }
        if ($ok -and -not ($settings -is [System.Management.Automation.PSCustomObject])) { $ok = $false }
    } else {
        $settings = New-Object PSObject
    }
    if (-not $ok) {
        Write-Host "  settings.json: could not be read safely, NOT changed. To skip permission prompts, add these to permissions.allow yourself:"
        $rules | ForEach-Object { Write-Host "    $_" }
    } else {
        if (Test-Path $settingsFile) { Backup-File $settingsFile 'settings.json' }
        if (-not $settings.PSObject.Properties['permissions']) {
            $settings | Add-Member -NotePropertyName permissions -NotePropertyValue (New-Object PSObject)
        }
        $allow = @()
        if ($settings.permissions.PSObject.Properties['allow']) { $allow = @($settings.permissions.allow) }
        foreach ($r in $rules) { if ($allow -notcontains $r) { $allow += $r } }
        $settings.permissions | Add-Member -NotePropertyName allow -NotePropertyValue ([object[]]$allow) -Force
        # Windows PowerShell 5.1 adds a bogus "Count" wrapper to arrays unless this type data is removed.
        Remove-TypeData System.Array -ErrorAction SilentlyContinue
        $json = $settings | ConvertTo-Json -Depth 64
        [System.IO.File]::WriteAllText($settingsFile, $json, $utf8NoBom)
        Write-Host "  settings.json: Codex worker permission added (backup kept)"
    }
}

Write-Host ""
$verFile = Join-Path $claudeDir 'relay-kit\VERSION'
if (Test-Path $verFile) { Write-Host ((Get-Content $verFile -TotalCount 1)) }
Write-Host "Done. Added: $new, replaced: $replaced, unchanged: $same"
if (Test-Path $backupDir) { Write-Host "Backups of replaced files: $backupDir" }
Write-Host "Installed into: $claudeDir"
Write-Host "Next: close and reopen Claude Code, then type /skills and /agents to check."
