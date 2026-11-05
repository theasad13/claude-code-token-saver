# codex-worker.ps1 - runs ONE relay task with Codex CLI (non-interactive).
# Usage (from the project root, on a relay/<batch-name> branch, clean git status):
#   powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\relay-kit\codex-worker.ps1" -TaskId TASK-001
#   optional: -Mode strict   -Model <name>   -Effort low|medium|high|xhigh
#
# Modes:
#   auto (default) - like interactive Codex with "ask only when risky":
#       Codex works inside its workspace-write sandbox. When it needs more (git commit, internet),
#       it requests escalation and Codex Auto-review (an automatic reviewer agent) approves
#       low/medium-risk requests and denies critical ones. Live web search is on.
#       The prompt below limits escalation to: committing this task's files, and read-only network.
#       Codex commits the task itself, like the Sonnet worker.
#   strict - sandbox only, no network, no approvals; .git is read-only, so Codex cannot commit.
#       The manager (Claude, relay-run) checks with verify.ps1 and makes the commit.
#
# This script lives outside the repo, so the worker cannot edit it.
# Logs: <repo>/.git/relay-logs/ (never committed, never shown by git status).
# Exit codes: 0 = Codex finished (manager must check next), 1 = Codex failed, 2 = setup problem.

param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [ValidateSet('auto', 'strict')][string]$Mode = 'auto',
    [string]$Model = '',
    [string]$Effort = ''
)

$ErrorActionPreference = 'Continue'
function Stop-Setup([string]$msg) { Write-Host "SETUP ERROR: $msg"; exit 2 }

$TaskId = $TaskId.Trim().ToUpper()
if ($TaskId -notmatch '^TASK-\d{3,}$') { Stop-Setup "Bad task id: $TaskId" }
if ($Model -and $Model -notmatch '^[A-Za-z0-9._:-]+$') { Stop-Setup "Bad model name: $Model" }
if ($Effort -and $Effort -notmatch '^(minimal|low|medium|high|xhigh)$') { Stop-Setup "Bad effort: $Effort" }

$root = (& git rev-parse --show-toplevel 2>$null)
if (-not $root) { Stop-Setup 'Not inside a git repository.' }
Set-Location $root

$branch = (& git branch --show-current 2>$null)
if ($branch -notlike 'relay/*') { Stop-Setup "Current branch is '$branch'. Expected relay/<batch-name>." }
if (-not (Test-Path "relay/tasks/$TaskId.md")) { Stop-Setup "Task file not found: relay/tasks/$TaskId.md" }
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Stop-Setup 'Codex CLI not found. Install it with: npm install -g @openai/codex   then run: codex login'
}
$dirty = & git status --porcelain
if ($dirty) { Stop-Setup ("Git status is not clean. Commit or review these first:`n" + ($dirty -join "`n")) }
$headBefore = (& git rev-parse HEAD)

$gitDir = (& git rev-parse --absolute-git-dir)
$logDir = Join-Path $gitDir 'relay-logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$promptFile = Join-Path $logDir "$TaskId-$stamp.prompt.txt"
$logFile = Join-Path $logDir "$TaskId-$stamp.log"
$lastFile = Join-Path $logDir "$TaskId-$stamp.last.txt"

if ($Mode -eq 'auto') {
    $prompt = @"
Do relay task $TaskId only. Follow relay/WORKER.md exactly, including the git commit at the end.
Permission policy from the project owner for this run:
- Work inside this repository's sandbox. If the sandbox blocks something, you MAY request escalated permission ONLY for:
  (a) git add / git commit of exactly this task's targets, its report and relay/STATUS.md (never git add -A or git add .);
  (b) read-only network access: web search, reading docs, curl/HTTP GET requests.
- Do NOT request escalation for anything else: no writing or deleting outside this repository, no installing packages,
  no git push, no git reset/rebase/checkout of other branches, no git config changes, no reading secrets or credential files.
- If the task needs something outside this policy, do not do it: write the reason in the report and set the task BLOCKED.
Stop after this task. Final message (max 5 lines): task id, DONE or BLOCKED, attempts used, files changed, commit hash, any question.
"@
    $flags = '--approve-for-me -c web_search=live'
} else {
    $prompt = @"
Do relay task $TaskId only. Follow relay/WORKER.md exactly.
You run in a sandbox where .git is read-only: do NOT run git add or git commit. Leave your changes uncommitted; the manager checks and commits them.
Stop after this task. Final message (max 5 lines): task id, DONE or BLOCKED, attempts used, files changed, any question.
"@
    $flags = '--sandbox workspace-write -c approval_policy=never -c sandbox_workspace_write.network_access=false'
}
Set-Content -Path $promptFile -Value $prompt -Encoding ascii

if ($Model) { $flags += " -m $Model" }
if ($Effort) { $flags += " -c model_reasoning_effort=$Effort" }
$codexCmd = 'codex exec ' + $flags + ' -C "' + $root + '" -o "' + $lastFile + '" - < "' + $promptFile + '" > "' + $logFile + '" 2>&1'

if ($Mode -eq 'auto') {
    Write-Host "Codex worker: $TaskId (mode auto: sandbox + Auto-review for risky requests, web search on, Codex commits)"
} else {
    Write-Host "Codex worker: $TaskId (mode strict: sandbox only, no network, no approvals, manager commits)"
}
Write-Host "Log: $logFile"

# Started through .NET so the command line reaches cmd.exe exactly as written.
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $env:ComSpec
if (-not $psi.FileName) { $psi.FileName = 'cmd.exe' }
$psi.Arguments = '/d /s /c "' + $codexCmd + '"'
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.WorkingDirectory = $root
$p = [System.Diagnostics.Process]::Start($psi)
$p.WaitForExit()
$exit = $p.ExitCode

Write-Host ""
Write-Host "---- Codex final message ----"
if (Test-Path $lastFile) { Get-Content $lastFile -Encoding UTF8 | ForEach-Object { Write-Host $_ } }
elseif (Test-Path $logFile) { Get-Content $logFile -Encoding UTF8 -Tail 30 | ForEach-Object { Write-Host $_ } }

Write-Host ""
Write-Host "---- STATUS row ----"
Select-String -Path 'relay/STATUS.md' -Pattern $TaskId -SimpleMatch | ForEach-Object { Write-Host $_.Line }

Write-Host ""
Write-Host "---- New commits ----"
$newCommits = @(& git log --oneline "$headBefore..HEAD")
if ($newCommits.Count -gt 0) { $newCommits | ForEach-Object { Write-Host $_ } } else { Write-Host "(none)" }
Write-Host "---- Uncommitted ----"
$after = @(& git status --porcelain)
if ($after.Count -gt 0) { $after | ForEach-Object { Write-Host $_ } } else { Write-Host "(clean)" }

if ($exit -ne 0) { Write-Host ""; Write-Host "CODEX FAILED (exit code $exit). See the log above."; exit 1 }
Write-Host ""
if ($Mode -eq 'auto') {
    Write-Host "CODEX FINISHED. Next (manager): check the new commit like a Sonnet task:"
    Write-Host "  git status clean, row DONE or BLOCKED, commit lists only targets + report + STATUS."
    Write-Host "  If Codex could not commit (changes still uncommitted): check them and commit as in strict mode."
} else {
    Write-Host "CODEX FINISHED. Next (manager): check git status and the STATUS row."
    Write-Host "  DONE    -> run relay/verify.ps1 -TaskId $TaskId (must PASS), then commit targets + report + STATUS."
    Write-Host "  BLOCKED -> only report + STATUS may change; commit them as `"${TaskId}: BLOCKED`"."
}
exit 0
