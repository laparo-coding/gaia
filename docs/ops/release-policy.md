# Release Policy

## Source of Truth

- Release source is strictly `main`.
- Deployable refs must be semantic tags in `vMAJOR.MINOR.PATCH` format.
- Tags must point to commits that already passed CI.

## Authorization

- Only repository admins can trigger deployment workflow.

## Governance Gates

- Required CI checks: format/lint, build, tests
- Required review gates: human approval, automated review gate pass, and zero unresolved blocking comments

## Artifact Rules

- Every successful deployment publishes:
  - signed IPA
  - symbols archive
  - release metadata
- Retain at least the three latest successful release bundles.
