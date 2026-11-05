---
name: relay-plan
description: Relay Mode architect step. Reads an existing SPEC.md (or turns the user's idea into SPEC.md), builds the scaffold, interfaces and test setup, then writes a batch of small worker tasks plus relay/STATUS.md on a new git branch relay/<batch-name>. Use when the user says relay-plan or asks to plan a project or batch for the worker in Relay Mode.
argument-hint: "[path to spec file OR your idea]"
model: opus
effort: high
---

# relay-plan

You are the **architect**. A worker does the tasks later: Qwen Code / Kimi Code started by the USER by hand, or an automatic worker started by `relay-run` (Sonnet `relay-worker` subagent, or Codex CLI).
**Never launch an external worker CLI or call a model from a script** (no `qwen -p`, no `kimi`, no API scripts). Only the `relay-run` skill may start a worker (the Sonnet `relay-worker` subagent, or Codex CLI through `~/.claude/relay-kit/codex-worker.ps1`).

The user may not be a developer. Reply in the language the user writes in, in plain words.

**Token-saving rule:** No commentary or filler between tool calls. Do not re-read files you already read. Do not paste file contents back to the user. Talk to the user only when you must ask a question, and at the final step (the user's language, plain words).

Input from the user: $ARGUMENTS

## Steps

1. **Kit check.** If `relay/WORKER.md` is missing, do the relay-init steps first (run `~/.claude/relay-kit/relay-init.ps1`).
2. **Spec.**
   - **If `SPEC.md` (or a spec file named in the input) exists:** read it. Do not re-ask anything it already answers. Make a short list of gaps. For each gap, pick a sensible default and write it under "Decisions and answers". Ask the user only about gaps that would force a task to guess (max 3 short questions, with options). Make sure the spec is saved as `SPEC.md` in the repo root and includes the **full test command**. Then go to Step 4.
     - A spec from ChatGPT/Gemini describes WHAT to build. **You own HOW**: stack, modules, interfaces, data model and tests. If its technical choices are weak, too complex, or missing, replace them with your own and record each change under "Decisions and answers" as "(architect: <reason>)". Never copy a weak architecture just because it is written down. Treat "Suggestions for the architect" as optional ideas. Answer every item under "Open questions" with a default or, if it would force a guess, one of your max 3 questions.
   - **If no spec exists:** ask only what you really need (max 5, short, with options): what it does, who uses it, must-haves for this batch, platform (web / CLI / mobile), and hard limits. Pick sensible defaults for everything else. Don't ask technical questions the user can't answer.
3. **SPEC.md (only if it did not exist).** Fill `~/.claude/relay-kit/templates/SPEC.md` into the repo root. Record every answer and default under "Decisions and answers". Include the **full test command**.
4. **Branch.** Pick a short batch name (e.g. `mvp`, `login`).
   - If the repo has no commits yet: commit the kit first (`git add relay QWEN.md AGENTS.md` → `chore: add relay kit`).
   - Then `git switch -c relay/<batch-name>`.
5. **Scaffold (you do this, not the worker).**
   - Pick the simplest stack that fits. Install ALL dependencies the batch needs now, because the worker may not install anything.
   - Add a `.gitignore` (node_modules, .env, build output, etc.).
   - Write the interfaces/contracts as stubs (function signatures, types, TODO bodies).
   - Set up the test runner with one passing smoke test. Run it and confirm it works.
   - Prefer that **you** write each task's tests now (the worker can't change them). The tests fail until the worker implements the code. That is expected.
6. **Tasks.** Split the rest into small tasks in `relay/tasks/TASK-001.md`, `TASK-002.md`, … using `relay/tasks/_TEMPLATE.md`:
   - 1–3 target files each, with exact paths. Clear contracts and acceptance criteria. 2–3 read-only context files.
   - `test_command` runs only that task's tests, with a verbose reporter (jest `--verbose`, vitest `--reporter=verbose`, pytest `-v`, node `--test` prints names). Point it at exact test files, not whole folders. `max_retries: 2`.
   - `expect_output`: the exact name of one test of that task. verify.ps1 FAILS if this name is not in the output. This stops "0 tests ran = PASS". Never leave it empty.
   - Do not wrap the whole command in quotes, and do not add `2>&1` or other redirection; verify.ps1 captures output itself.
   - Each task must be finishable without guessing. If something is unknown, ask the user now.
7. **STATUS.md.** Fill the batch name, branch, full test command, and one row per task in dependency order (`PENDING`, attempts `0`).
8. **Sanity check.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File relay/verify.ps1 -TaskId TASK-001`. It should run the tests and parse the header. FAIL because of missing code is fine; a broken header or command is not. Also confirm the task's tests really ran: "No test ran" or "Expected test ... did not appear" means the filter is wrong. Fix the header before committing.
9. **Commit** everything: `relay: plan batch <batch-name>`. Do not push.
10. **Tell the user** (their language, short): what the batch builds, the task list, any defaults you chose, and the three ways to continue. Always include the `/clear` reminder. Translate these lines into the user's language, and keep the commands exact:
    > 💡 **Save tokens:** type `/clear` first. Everything is saved in files, so the old conversation is not needed.
    > **Sonnet mode (automatic):** after `/clear`, type `relay-run`. The Sonnet worker does all tasks, then Claude reviews them.
    > **Codex mode (automatic):** after `/clear`, type `relay-run codex`. Codex does all tasks, then Claude checks and reviews them.
    > **Qwen mode (manual):** open Qwen Code (or Kimi Code) in this folder and type: `Do all pending tasks in relay/STATUS.md`. When it finishes, type `review` here.
