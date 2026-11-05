---
name: relay-run
description: Relay Mode automatic worker step. Runs every PENDING task in relay/STATUS.md through an automatic worker, one task at a time - the Sonnet relay-worker subagent (default) or Codex CLI (codex mode) - then reviews the batch with relay-review, with at most 2 fix rounds. Use when the user says relay-run, asks to run the batch with Sonnet or Codex, or wants the batch done automatically without Qwen.
argument-hint: "[sonnet|codex|codex strict] [optional task id]"
model: opus
effort: low
---

# relay-run

You are the **architect and manager**. You do not write task code yourself. A worker writes it:
- **sonnet** (default): the `relay-worker` subagent.
- **codex**: Codex CLI, started ONLY through `~/.claude/relay-kit/codex-worker.ps1` (fixed safe settings).

Never launch any other external CLI or model (no `qwen -p`, no `kimi`, no `claude -p`, no direct `codex` command, no API scripts).

The user may not be a developer. Reply in the language the user writes in, in plain words, only at the end or when you must stop.

**Token-saving rule:** No commentary between tool calls. Do not re-read task files or code yourself; the worker reads them. Keep each worker prompt short.

Input from the user: $ARGUMENTS
(Worker = `codex` if the input contains "codex", otherwise `sonnet`. Codex mode = `strict` if the input contains "strict", otherwise `auto`. A task id in the input means run only that task.)

## Steps

1. **Check.**
   - `relay/STATUS.md` must exist and the current branch must be `relay/<batch-name>`. If not, stop and tell the user to run `relay-plan` first.
   - sonnet: `~/.claude/agents/relay-worker.md` must exist. codex: `~/.claude/relay-kit/codex-worker.ps1` must exist and `codex login status` must say logged in. If not, stop and tell the user what is missing.
   - `git status` must be clean. If not, list the files and stop. Do not delete anything.
   - Set `Worker mode: sonnet-auto` or `codex-auto` in STATUS.md, and commit it (`relay: worker mode <mode>`), so the tree is clean.

2. **Run tasks, one at a time, in STATUS.md order.** Never run two workers at the same time.
   For each task with status `PENDING` (or only the task id given in the input):
   - Skip it if any `depends_on` task is not `DONE` or `REVIEWED`.
   - **sonnet:** start the `relay-worker` subagent with this prompt only:
     `Do relay task <TASK-ID> only. Follow relay/WORKER.md exactly. Stop after this task.`
     Then check with git (do not read the code): `git status` is clean, the task row is `DONE` or `BLOCKED`, and `git show --name-only --format= HEAD` lists only that task's targets, its report and `relay/STATUS.md`.
   - **codex:** run, in the background (it can take several minutes), and wait for it to finish:
     `powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude/relay-kit/codex-worker.ps1" -TaskId <TASK-ID>`
     (add ` -Mode strict` for strict mode).
     - **auto mode (default):** Codex works in its sandbox, risky requests go to Codex Auto-review, and Codex commits the task itself.
       Check it exactly like a Sonnet task: `git status` clean, the row is `DONE` or `BLOCKED`, `git show --name-only --format= HEAD` lists only that task's targets, its report and `relay/STATUS.md`.
       If Codex finished but left its changes uncommitted, check and commit them as in strict mode below.
     - **strict mode:** Codex cannot commit (its sandbox keeps `.git` read-only). You check and commit:
     - The task row must be `DONE` or `BLOCKED`.
     - `git status --porcelain` may list only that task's targets, its report and `relay/STATUS.md`.
     - If `DONE`: run `powershell -NoProfile -ExecutionPolicy Bypass -File relay/verify.ps1 -TaskId <TASK-ID>` yourself. It must print PASS.
       Then `git add` exactly those files and `git commit -m "<TASK-ID>: <title>"`.
     - If `BLOCKED`: only the report and STATUS.md may be changed. `git add` them and `git commit -m "<TASK-ID>: BLOCKED"`.
   - If any check fails (forbidden file, verify FAIL on a DONE task, missing status, codex exit code not 0): stop the whole run. Do not commit, do not revert, do not delete. Tell the user exactly what is wrong and suggest `relay-review`.

3. **Review.** When no runnable `PENDING` task is left, invoke the `relay-review` skill and follow it. Do not merge inside this step.

4. **Fix rounds (max 2).** If the review set any task back to `PENDING` with feedback, repeat Steps 2 and 3 with the same worker. After 2 fix rounds, stop even if tasks still fail. Those tasks need the user or a better task description.

5. **Final message** (their language, short):
   - Table: task | result (✅ REVIEWED / 🔁 still failing / ❓ needs your answer / ⏭ skipped) | one line.
   - Full test suite result.
   - Questions for the user, if any.
   - If everything is REVIEWED and tests pass: ask, in their language, "Everything looks good. Should I merge into the main branch?" Merge only after a clear yes, as relay-review Step 7 says.
   - One line about quota: Sonnet worker uses the Claude plan; Codex worker uses the ChatGPT plan.
