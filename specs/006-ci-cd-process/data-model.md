# Data Model: CI/CD Process for iPad-Only Distribution

## Entity: PipelineStage

- Purpose: Represents one CI/CD stage.
- Fields:
  - `id` (string)
  - `name` (string)
  - `kind` (enum: ci|deploy)
  - `status` (enum: pending|running|passed|failed|skipped)
  - `startedAt` (datetime)
  - `finishedAt` (datetime)
- Validation rules:
  - `status` transitions must follow execution order.
  - `kind=deploy` requires successful CI dependency.

## Entity: ReviewGatePolicy

- Purpose: Defines mandatory review and quality gates required before deployment.
- Fields:
  - `sourcePolicy` (enum: mirrorAitherApplicable)
  - `requiresHumanApproval` (boolean)
  - `requiresAutomatedReviewGate` (boolean)
  - `blocksOnUnresolvedBlockingComments` (boolean)
- Validation rules:
  - Deployment cannot start unless all required review gates are satisfied.

## Entity: SigningBundle

- Purpose: Describes signing inputs needed for deploy builds.
- Fields:
  - `teamId` (string)
  - `bundleId` (string)
  - `certificateRef` (string)
  - `provisioningProfileRef` (string)
  - `expiresAt` (datetime)
- Validation rules:
  - All refs must be present before deploy stage starts.
  - `expiresAt` must be in the future at deploy trigger time.

## Entity: ReleaseArtifact

- Purpose: Captures outputs from a deployment run.
- Fields:
  - `releaseId` (string)
  - `commitSha` (string)
  - `ipaPath` (string)
  - `symbolsPath` (string)
  - `metadataPath` (string)
  - `tag` (string)
  - `createdAt` (datetime)
- Validation rules:
  - All artifact paths must exist before marking deployment as successful.
  - `tag` must match `vMAJOR.MINOR.PATCH`.

## Entity: DeploymentRun

- Purpose: Represents one operator-triggered deployment attempt.
- Fields:
  - `runId` (string)
  - `triggeredBy` (string)
  - `triggeredByRole` (enum: admin|nonAdmin)
  - `targetCommit` (string)
  - `targetBranch` (string)
  - `targetTag` (string)
  - `status` (enum: pending|running|succeeded|failed|aborted)
  - `logRef` (string)
  - `artifactRef` (string)
- Validation rules:
  - `targetCommit` must map to a successful CI run.
  - `triggeredByRole` must be `admin`.
  - `targetBranch` must be `main`.
  - `targetTag` must match `vMAJOR.MINOR.PATCH` and reference `main`.
  - Failed runs must include diagnostic log reference.

## Entity: RollbackCandidate

- Purpose: A previously successful release eligible for rollback.
- Fields:
  - `releaseId` (string)
  - `commitSha` (string)
  - `verifiedOnDevice` (boolean)
  - `artifactRef` (string)
  - `retentionRank` (integer)
- Validation rules:
  - Only successful deployment artifacts may be rollback candidates.
  - At least three latest successful artifacts must remain available.

## State Transitions

1. CI pipeline transitions `pending -> running -> passed|failed`.
2. Deploy eligibility requires: CI passed, Aither-aligned review gates passed, source is semver tag on `main`, and trigger actor is admin.
3. Deployment transitions `pending -> running -> succeeded|failed|aborted`.
4. Rollback selection is limited to `succeeded` deployments with valid artifacts.
5. Retention policy keeps at least three latest successful rollback candidates.