# Relay Worker Rules

You are the **worker**. An architect (Claude) planned this batch. You implement small tasks.
These rules apply to any worker: Qwen Code, Kimi Code, Codex, a Claude Sonnet subagent, or another tool.

## What to do

1. Open `relay/STATUS.md`. Work through rows with status `PENDING`, top to bottom.
   - If a task file has a `Feedback:` line at the top, read that feedback file first. It says what to fix.
   - Skip a task if any task in its `depends_on` is not `DONE` or `REVIEWED`. Note it in the final summary.
2. Read the task file `relay/tasks/TASK-XXX.md` fully. Read only its listed context files.
3. Implement the task. Change **only** the files in its `targets` list.
4. Run the check:
   `powershell -NoProfile -ExecutionPolicy Bypass -File relay/verify.ps1 -TaskId TASK-XXX`
5. If it prints **FAIL**: read the output (it shows only the last 40 test lines; add `-Full` only if that is not enough), fix your code, run the check again.
   You may retry **at most 2 times** (3 runs in total). Add 1 to `attempts` in STATUS.md for each retry.
6. If it prints **PASS**:
   - Write `relay/reports/TASK-XXX.md` (use `relay/reports/_TEMPLATE.md`).
   - Set the task to `DONE` in STATUS.md.
   - Commit: `git add <targets> relay/reports/TASK-XXX.md relay/STATUS.md`
     then `git commit -m "TASK-XXX: <title>"`.
   - If your sandbox does not allow git writes (for example Codex): skip `git add` and `git commit`, and leave the changes uncommitted. The manager checks and commits them.
7. If it still fails after 2 retries:
   - Undo your changes to that task's target files only: `git restore -- <file>` for files that existed; delete target files you created.
   - Write the report with the last error and what you tried.
   - Set the task to `BLOCKED`. Commit only the report and STATUS.md (or leave them uncommitted if git writes are blocked). Move to the next task.
8. When no `PENDING` task is left, print a short summary: done / blocked / skipped / open questions.

## Never

- Never change files outside the task's `targets` (except its report and `relay/STATUS.md`).
- Never edit: `relay/WORKER.md`, `relay/verify.ps1`, any file in `relay/tasks/`, test files the task does not list as targets, `.claude/`, `QWEN.md`, `AGENTS.md`, `CLAUDE.md`, `.env` or any secret file, dependency files (package.json, requirements.txt, pyproject.toml, lock files), CI or deploy files.
- Never install packages, push, deploy, change git config, or delete branches.
- Never weaken, skip, or delete a test to make it pass.
- Never invent missing requirements. If the task is unclear, write your question in the report, set `BLOCKED`, and move on.
- Never print or copy secrets, keys, or passwords.
