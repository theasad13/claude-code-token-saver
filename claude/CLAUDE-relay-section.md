
<!-- relay-mode:start -->
## Relay Mode
- Explain results in plain words, in the language the user writes in.
- Skills: `relay-init` (add kit to repo), `relay-plan` (spec + scaffold + tasks), `relay-run` (automatic worker does tasks, then review; `relay-run codex` uses Codex), `relay-review` (check worker's work).
- Worker modes: Sonnet subagent `relay-worker` (automatic, via relay-run), Codex CLI (automatic, via `relay-run codex`), or Qwen/Kimi Code (the user starts them by hand).
- Never launch Qwen, Kimi or any external model CLI or API from a script.
- Exception: Codex CLI may be started, but ONLY by relay-run through `~/.claude/relay-kit/codex-worker.ps1` (one task at a time; default auto mode = sandbox + Codex Auto-review for risky requests, Codex commits; `strict` mode = no network, no approvals, Claude commits).
- Never push, deploy, or merge to main without the user's clear yes. Never put secrets in files, prompts or commits.
<!-- relay-mode:end -->
