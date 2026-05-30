# Quickstart Validation: CI/CD Process for iPad-Only Distribution

Use this document to validate process behavior once implementation begins.

## Scenario 1: PR quality gate

1. Open a pull request against `main`.
2. Confirm CI runs lint/format checks, build, and tests.
3. Confirm merge is blocked when any mandatory check fails.

Expected result:
- CI status is deterministic and visible to operator.

## Scenario 2: Manual deployment trigger

1. Select a release tag on `main` in format `vMAJOR.MINOR.PATCH` with successful CI status.
2. Trigger deployment workflow manually as a repository admin.
3. Confirm required review gates aligned with Aither policy are already satisfied.
4. Confirm signed IPA, symbols, and metadata are produced.

Expected result:
- Deployment completes only from validated commits.

## Scenario 3: Deploy authorization guard

1. Attempt to trigger deployment as a non-admin actor.

Expected result:
- Deployment is denied before packaging starts.

## Scenario 4: Invalid release source/tag

1. Attempt deployment from a non-`main` source or non-semver tag.

Expected result:
- Deployment is rejected with clear diagnostics.

## Scenario 5: Missing signing input

1. Simulate missing or expired provisioning profile secret.
2. Trigger deployment workflow.

Expected result:
- Deployment fails early with clear diagnostics.
- No partial success state is reported.

## Scenario 6: Direct device installation

1. Download produced IPA artifact.
2. Install on registered iPad through the selected distribution path.

Expected result:
- Installation succeeds without App Store publishing.

## Scenario 7: Rollback

1. Verify at least the last three successful release artifacts are available.
2. Choose a previous successful release artifact.
3. Re-run deploy path using stored artifact metadata.

Expected result:
- Previous stable build is restored without rebuilding from source.