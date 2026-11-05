# relay/verify.ps1
# Checks one Relay task. No model calls. No installs.
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File relay/verify.ps1 -TaskId TASK-001
# Exit codes: 0 = PASS, 1 = FAIL, 2 = setup or header error.
# The worker must NEVER edit this file.

param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [int]$TailLines = 40,
    [switch]$Full
)

$ErrorActionPreference = 'Continue'

function Write-Result([string]$status, [string]$msg) {
    Write-Host ""
    Write-Host "==== $status : $TaskId ===="
    if ($msg) { Write-Host $msg }
}

function Normalize([string]$p) {
    $p = $p.Trim().Trim('"').Replace('\', '/')
    if ($p.StartsWith('./')) { $p = $p.Substring(2) }
    return $p
}

# --- Go to repo root -------------------------------------------------------
$root = (& git rev-parse --show-toplevel 2>$null)
if (-not $root) { Write-Result 'ERROR' 'Not inside a git repository.'; exit 2 }
Set-Location $root

# --- Read task header -------------------------------------------------------
$taskFile = "relay/tasks/$TaskId.md"
if (-not (Test-Path $taskFile)) { Write-Result 'ERROR' "Task file not found: $taskFile"; exit 2 }

$lines = Get-Content -Path $taskFile -Encoding UTF8
$start = -1; $end = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq '---') {
        if ($start -lt 0) { $start = $i } else { $end = $i; break }
    }
}
if ($start -lt 0 -or $end -lt 0) { Write-Result 'ERROR' "No header block (--- ... ---) in $taskFile"; exit 2 }

$targets = New-Object System.Collections.Generic.List[string]
$testCommand = $null
$expectOutput = $null
$inTargets = $false
for ($i = $start + 1; $i -lt $end; $i++) {
    $line = $lines[$i]
    if ($line -match '^\s*targets\s*:\s*$') { $inTargets = $true; continue }
    if ($inTargets -and $line -match '^\s*-\s*(.+?)\s*$') { $targets.Add((Normalize $Matches[1])); continue }
    if ($line -match '^\S') { $inTargets = $false }
    if ($line -match '^\s*expect_output\s*:\s*(.+?)\s*$') { $expectOutput = $Matches[1].Trim().Trim('"').Trim("'") }
    if ($line -match '^\s*test_command\s*:\s*(.+?)\s*$') {
        $testCommand = $Matches[1].Trim()
        # Remove ONE pair of wrapping quotes only (YAML style). Never touch quotes inside the
        # command, e.g. npx jest -t "adds numbers" must keep its closing quote.
        if ($testCommand.Length -ge 2) {
            $f = $testCommand[0]; $l = $testCommand[$testCommand.Length - 1]
            if (($f -eq '"' -and $l -eq '"') -or ($f -eq "'" -and $l -eq "'")) {
                $inner = $testCommand.Substring(1, $testCommand.Length - 2)
                if (-not $inner.Contains([string]$f)) { $testCommand = $inner }
            }
        }
    }
}

if ($targets.Count -eq 0) { Write-Result 'ERROR' 'Header has no targets list.'; exit 2 }
if (-not $expectOutput) { Write-Host "WARNING: header has no expect_output. Add one test name so a run with 0 tests can never PASS." }
if (-not $testCommand) { Write-Result 'ERROR' 'Header has no test_command.'; exit 2 }

$allowed = New-Object System.Collections.Generic.List[string]
foreach ($t in $targets) { $allowed.Add($t) }
$allowed.Add("relay/reports/$TaskId.md")
$allowed.Add('relay/STATUS.md')

Write-Host "Task: $TaskId | test: $testCommand"

# --- Check 1: changed files ------------------------------------------------
$status = & git -c core.quotepath=false status --porcelain -uall
$bad = New-Object System.Collections.Generic.List[string]
foreach ($s in $status) {
    if (-not $s -or $s.Length -lt 4) { continue }
    $path = $s.Substring(3)
    if ($path -like '* -> *') { $path = ($path -split ' -> ')[-1] }
    $path = Normalize $path
    # Ignore generated junk that tests create (should also be in .gitignore)
    if ($path -match '(^|/)(__pycache__|\.pytest_cache|node_modules|\.venv|venv|coverage|\.coverage)(/|$)' -or $path -match '\.pyc$') { continue }
    if (-not ($allowed -contains $path)) { $bad.Add($path) }
}

# --- Check 2: tests ----------------------------------------------------------
# Test output is captured, not printed in full, to save the model's tokens.
# PASS: nothing printed. FAIL: only the last $TailLines lines. Use -Full to see everything.
#
# The command runs in its own process. It is passed to the shell exactly as written in the
# task header: nothing is appended to it (an appended "2>&1" used to get glued onto -t / -k
# filters, so filters matched no tests and the check passed without running any test).
# stdout and stderr are captured by .NET, not by shell redirection.
function Invoke-TestCommand([string]$cmdLine) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($env:OS -eq 'Windows_NT') {
        $psi.FileName = $env:ComSpec
        if (-not $psi.FileName) { $psi.FileName = 'cmd.exe' }
        # /s + outer quotes: cmd removes only the outer pair and keeps inner quotes intact.
        $psi.Arguments = '/d /s /c "' + $cmdLine + '"'
    } else {
        $psi.FileName = '/bin/sh'
        $psi.ArgumentList.Add('-c')
        $psi.ArgumentList.Add($cmdLine)
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = (Get-Location).Path
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    $p.WaitForExit()
    $text = $outTask.Result
    if ($errTask.Result) { $text = $text + "`n" + $errTask.Result }
    return @{ Exit = $p.ExitCode; Lines = @($text -split "\r?\n") }
}

$testExit = 1
$testOut = @()
try {
    $r = Invoke-TestCommand $testCommand
    $testExit = $r.Exit
    $testOut = $r.Lines
} catch {
    $testOut = @("Test command could not run: $($_.Exception.Message)")
    $testExit = 1
}

# Guard: a run where no test executed is never a PASS, even with exit code 0.
$noTests = $false
$joined = ($testOut -join "`n")
$noTestPatterns = @(
    '(?i)no tests? (were )?(found|ran|run|collected|executed)',
    '(?i)no test files found',
    '(?i)\bRan 0 tests?\b',
    '(?i)\b0 tests? (ran|run|passed|executed)\b',
    '(?im)^\s*#\s*(tests|pass)\s+0\s*$',
    '(?i)\b0 passing\b',
    '(?i)\bcollected 0 items\b',
    '(?im)^\s*Tests:\s+(?!.*\b[1-9]\d* passed).*\btotal\b',
    '(?im)^\s*Tests\s+(?!.*\b[1-9]\d* passed)\d+ (skipped|todo).*\(\d+\)'
)
foreach ($pat in $noTestPatterns) {
    if ($joined -match $pat) { $noTests = $true; break }
}
# Strong check: the header can name one test that MUST appear in the output.
$expectMissing = $false
if ($expectOutput -and -not $joined.Contains($expectOutput)) { $expectMissing = $true }

if ($Full -or $testExit -ne 0 -or $noTests -or $expectMissing) {
    $lines = @($testOut | ForEach-Object { "$_" })
    if (-not $Full -and $lines.Count -gt $TailLines) {
        Write-Host ""
        Write-Host "---- Test output: last $TailLines of $($lines.Count) lines (run with -Full for all) ----"
        $lines = $lines[($lines.Count - $TailLines)..($lines.Count - 1)]
    } else {
        Write-Host ""
        Write-Host "---- Test output ----"
    }
    $lines | ForEach-Object { Write-Host $_ }
}

# --- Result ------------------------------------------------------------------
$problems = @()
if ($testExit -ne 0) { $problems += "Tests failed (exit code $testExit)." }
elseif ($expectMissing) { $problems += "Expected test '$expectOutput' did not appear in the test output, so it probably did not run. Check the test_command filter (and use a verbose reporter)." }
elseif ($noTests) { $problems += "No test ran (0 tests found, or all skipped). Check the test_command filter in the task header. A run with no tests is never a PASS." }
if ($bad.Count -gt 0) { $problems += "Files changed outside this task's targets: $($bad -join ', ')" }

if ($problems.Count -eq 0) {
    Write-Result 'PASS' 'Tests passed and only allowed files changed.'
    exit 0
} else {
    Write-Result 'FAIL' ($problems -join "`n")
    exit 1
}
