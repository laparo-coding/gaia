---
name: push
description: Brings local changes to the main branch
model: Claude Haiku
---
- Run `swift format lint`, `swift build`, and `swift test`; stop on failure.
- Review the diff, branch, remote, and changed files before committing.
- Commit and push only after explicit user confirmation.
- Open or update the pull request and wait for required CI checks and approvals.
- Resolve review comments without bypassing branch protection.
- Merge only after explicit user confirmation and verified required checks.
