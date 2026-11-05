---
id: TASK-000
title: <short title>
depends_on: []
targets:
  - path/to/file_to_create_or_change.ext
test_command: <command that runs ONLY this task's tests, with a verbose reporter>
expect_output: <exact name of one test of this task; it must appear in the test output>
max_retries: 2
---

# TASK-000: <short title>

## Objective
One sentence: what this task builds.

## Context files (read-only)
- path/to/interface_or_stub.ext
- path/to/related_test.ext

## Contracts
Exact function or class signatures, input and output types, error cases.

## Acceptance criteria
- Observable result 1
- Observable result 2

## Tests
- Test file: path/to/test_file.ext (written by the architect; the worker must not change it)
- Cases covered: normal, edge, invalid input, ...
- Run: `<same as test_command>`

## Restrictions
- Change only the targets above.
- No new dependencies. No network calls unless stated. No secrets.

## Completion
verify.ps1 prints PASS -> report -> STATUS DONE -> commit "TASK-000: <title>".
