# Rollback Runbook

This runbook describes rollback operations from previously successful release artifacts.

## Candidate Selection

1. Select a release with successful deployment status.
2. Prefer the most recent stable candidate with verified device behavior.
3. Ensure at least three latest successful bundles are retained.

## Validation Before Rollback

1. Confirm artifact bundle is complete (IPA, symbols, metadata).
2. Confirm metadata contains release tag and commit SHA.
3. Confirm artifact integrity checks succeed.

## Redeploy Steps

1. Choose rollback candidate release ID.
2. Trigger rollback/deploy path using stored metadata.
3. Publish rollback execution logs.

## Verification After Rollback

1. Confirm build installs on iPad.
2. Confirm core functional smoke checks pass.
3. Confirm monitoring and crash symbol linkage is intact.

## Incident Follow-Up

1. Document rollback trigger reason.
2. Capture root cause and preventive actions.
3. Open a remediation task if failure source is unresolved.
