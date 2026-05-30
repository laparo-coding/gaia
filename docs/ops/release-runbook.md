# Release Runbook

This runbook describes how repository admins trigger iPad deployment from a semver tag on `main`.

## Preconditions

1. Tag format is `vMAJOR.MINOR.PATCH`.
2. Tag points to a commit on `main`.
3. CI baseline is green for that commit.
4. Review gate policy is satisfied:
	- human approval present
	- automated review gate passed
	- no unresolved blocking comments
5. Signing secrets are available and valid.

## Trigger Steps

1. Open GitHub Actions `Deploy iPad Build` workflow.
2. Start `workflow_dispatch` and provide `release_tag`.
3. Confirm actor role is authorized (repository admin).

## Artifact Verification

After run completion, verify all artifacts exist:

1. Signed IPA
2. Symbols archive
3. Release metadata with commit/tag/timestamp

## Post-Deploy Checks

1. Confirm artifact download works.
2. Confirm iPad installation path is operational.
3. Record run ID and artifact IDs in release notes.

## Failure Handling

1. Read failing stage logs and capture root cause.
2. Do not mark release successful on partial artifact output.
3. Resolve issue and rerun from a valid source tag.
