# Workflow Contract: CI/CD Process for iPad-Only Distribution

## Purpose

Define workflow-level interface expectations for CI and deployment.

## CI Contract

### Trigger

- `pull_request` to `main`
- `push` to `main`

### Required Stages

1. `lint-format`
2. `build`
3. `test`
4. `review-gates` (Aither-applicable mandatory review checks)

### Inputs

- Repository checkout at target commit
- Toolchain configuration for Swift/Xcode build steps

### Outputs

- Pass/fail status per stage
- Aggregated check status for branch protection
- Logs for each stage

### Failure Contract

- Any failed required stage marks CI as failed
- Merge gate must remain closed while CI is failing

## Deployment Contract

### Trigger

- `workflow_dispatch` (manual)

### Preconditions

- Target commit has successful CI run
- Target source is a tag on `main`
- Tag format matches `vMAJOR.MINOR.PATCH`
- Triggering actor is repository admin
- Required signing secrets and profile references are available
- Aither-applicable mandatory review gates are satisfied

### Required Stages

1. `validate-preconditions`
2. `archive-build`
3. `sign-and-export-ipa`
4. `publish-artifacts`

### Outputs

- Signed IPA artifact
- Symbol artifact (dSYM or equivalent)
- Release metadata (build number, commit, timestamp)
- Release tag and source branch provenance

### Failure Contract

- Failed deployment must emit operator-readable diagnostics
- Failed deployment must not produce a success marker
- Failure reason must identify which precondition failed (review gate, source/tag policy, trigger authorization, signing, or packaging)

## Rollback Contract

### Trigger

- Manual operator action against a previous successful release

### Preconditions

- Artifact bundle from selected release is available
- At least the latest three successful release bundles are retained

### Output

- Redeployable package information and confirmation log
