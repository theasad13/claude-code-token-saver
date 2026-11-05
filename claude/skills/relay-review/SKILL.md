---
name: relay-review
description: Relay Mode reviewer step. After the worker (Qwen Code, Kimi Code, Codex, or the Sonnet relay-worker) finishes a batch, checks every task's report, runs verify.ps1, checks each commit only touched allowed files, runs the full test suite, reviews code quality and security, then writes feedback files for anything the worker must fix. Use when the user says review, relay-review, or asks to check the worker's work.
argument-hint: "[optional: task id, e.g. TASK-003]"
model: opus
effort: medium
---

# relay-review

You are the **reviewer**. The worker already ran (Qwen/Kimi started by the user, or the Sonnet relay-worker or Codex via relay-run).
**Never launch an external worker CLI or call a model from a script** (no `qwen -p`, no `kimi`, no API scripts). Only the `relay-run` skill may start a worker (the Sonnet `relay-worker` subagent, or Codex CLI through `~/.claude/relay-kit/codex-worker.ps1`).

The user may not be a developer. Reply in the language the user writes in, in plain words.

**Token-saving rule:** No commentary or filler between tool calls. Do not re-read files you already read. Read diffs, not whole files, unless a diff is unclear. Run verify.ps1 without -Full; use -Full only if the last 40 lines do not explain the failure. If a task's diff touches security, money, auth or data deletion, think harder there. Do not paste code back to the user. Talk to the user only for questions and the final step (the user's language, plain words).

Input from the user: $ARGUMENTS
(If a task id is given, review only that task. Otherwise review every task with status DONE or BLOCKED.)

## Steps

1. **State check.**
   - Read `relay/STATUS.md`. Note the batch branch and the full test command.
   - Make sure the current branch is that `relay/<batch-name>` branch. If not, stop and tell the user.
   - Run `git status`. If there are uncommitted changes, list them. Do not delete them. Treat any uncommitted change as a finding for the task that owns that file.

2. **Per task (DONE).** For each task marked DONE:
   - Read its task file and `relay/reports/TASK-XXX.md`.
   - Find its commit: `git log --oneline --grep "TASK-XXX"`. Missing commit = finding.
   - List the files in that commit: `git show --name-only --format= <commit>`. Every file must be one of the task's `targets`, its report, or `relay/STATUS.md`. Anything else = **forbidden change** finding.
   - The worker must not change test files you wrote, `relay/WORKER.md`, `relay/verify.ps1`, task files, `.claude/`, `.env`, dependency files (package.json, requirements.txt, lock files), CI or deploy files. Any such change = **serious** finding.
   - Run `powershell -NoProfile -ExecutionPolicy Bypass -File relay/verify.ps1 -TaskId TASK-XXX`. It must print PASS. If the header has no `expect_output`, or verify printed the WARNING about it, run the task's tests yourself once to confirm they ran, and add `expect_output` to the task file.
   - Read the diff (`git show <commit>`). Check it against the task's contracts and acceptance criteria. Check for: hard-coded secrets or keys, unsafe shell/eval calls, network calls the task did not ask for, deleted error handling, tests weakened or skipped, obvious bugs the tests miss.

3. **Per task (BLOCKED).** Read the report and the worker's questions.
   - If the answer is in SPEC.md or is a clear technical choice, write the answer into the task file under a new "Clarification" section.
   - If it needs the user's decision, collect the question for the final step. Do not guess.

4. **Full suite.** Run the full test command from STATUS.md once. Record pass/fail counts. A failure that no single task explains = integration finding. You may fix small integration glue yourself if it is outside every task's targets; list each fix you make.

5. **Decide per task.**
   - **Pass** (verify PASS, allowed files only, criteria met, no serious issue): set status `REVIEWED` in STATUS.md.
   - **Needs fix:** write `relay/feedback/TASK-XXX.md` with: what is wrong (file + line), what the correct behavior is, which files the worker may change, and the test command to confirm. Add a line at the top of the task file: `Feedback: relay/feedback/TASK-XXX.md (read this first)`. Set status back to `PENDING` and attempts to `0`.
   - **Forbidden or serious change:** do not try to repair it silently. Revert that commit with `git revert --no-edit <commit>` (never reset or force), write the feedback file as above, set `PENDING`, and tell the user clearly.
   - **BLOCKED with clarification written:** set `PENDING`, attempts `0`.
   - **BLOCKED needing the user:** leave `BLOCKED`.

6. **Commit** your review changes: `relay: review batch <batch-name>`. Do not push.

7. **Merge only with permission.** If every task is `REVIEWED` and the full suite passes, ask the user, in their language: "Everything looks good. Should I merge into the main branch?" Merge only after a clear yes, with `git merge --no-ff relay/<batch-name>` from the main branch. Never push, deploy, or delete branches.
   After the merge, tell the user: "✅ Batch finished. 💡 Now type `/clear`, then start new work with `relay-plan`."

8. **Tell the user** (their language, short):
   - A table: task | result (✅ REVIEWED / 🔁 needs fix / ⛔ forbidden change / ❓ needs your answer) | one-line reason.
   - Full suite result.
   - Any question the user must answer.
   - The exact next step, one of:
     > 💡 Type `/clear` first (the feedback is saved in files).
     > Sonnet mode: type `relay-run` (Sonnet redoes the tasks that need fixes).
     > Codex mode: type `relay-run codex` (Codex redoes the tasks that need fixes).
     > Qwen mode: in Qwen Code (or Kimi Code) type: `Do all pending tasks in relay/STATUS.md. Read any feedback file mentioned at the top of a task first.` Then type `review` here.
     or, if all passed: the merge question from Step 7.
   - If you were called from `relay-run`, return this summary to it instead of asking about the next step.
