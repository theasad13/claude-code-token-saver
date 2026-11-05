---
name: relay-init
description: Adds the Relay Mode kit (relay/WORKER.md, STATUS.md, verify.ps1, task and report templates, QWEN.md, AGENTS.md) into the current project without overwriting existing files. Use when the user says relay-init or wants to enable Relay Mode in a repo.
---

# relay-init

1. Run, from the project root:
   `powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude/relay-kit/relay-init.ps1"`
2. If it reports that `QWEN.md` or `AGENTS.md` already existed with other content, append this one line to each (do not remove anything):
   `Read and follow relay/WORKER.md before doing anything.`
3. Do not commit yet. relay-plan commits the kit.
4. Tell the user in their own language, in plain words (2-3 lines): the kit was added, which files were created, and the next step:
   > Now type: `relay-plan <your idea>` (or the path to a SPEC.md)
