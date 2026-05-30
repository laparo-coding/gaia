# Feature Specification: CI/CD Process for iPad-Only Distribution

**Feature Branch**: `006-ci-cd-process`  
**Created**: 2026-05-30  
**Status**: Draft  
**Input**: User description: "Gaia will only run on my iPad. No Appstore needed. Build the best CI/CD workflow for this case."

## Clarifications

### Session 2026-05-30

- Q: Which code-review gate from the Aither CI/CD baseline must be required before Gaia deployment can run? → A: Require at least one human approval, require the configured automated review gate to pass, and block deployment when unresolved blocking comments exist.
- Q: Which release source should be allowed to trigger deployment (matching the Aither-style governance intent)? → A: Only tagged releases on main.
- Q: Which tag format should Gaia require for deployment-eligible releases on main? → A: Semantic version tags only (`vMAJOR.MINOR.PATCH`).
- Q: Which rollback readiness policy should Gaia require for deployment artifacts? → A: Keep last 3 successful release artifacts.
- Q: Which deployment trigger authorization model should Gaia require? → A: Only repository admins can trigger deploy.

## User Scenarios & Testing

### Primary User Story

As the sole Gaia operator, I want a reliable CI/CD process for iPad-only usage,
so every build is validated automatically and I can deploy signed app builds to my device
without App Store publishing.

### Acceptance Scenarios

1. **Given** a pull request is opened, **When** CI runs, **Then** formatting, build, and tests complete automatically and block merge on failure.
2. **Given** main is ready for release, **When** a release workflow is triggered, **Then** a signed IPA and debug symbols are produced as traceable artifacts.
3. **Given** the target iPad is registered for ad hoc distribution, **When** deployment artifacts are generated, **Then** installation can be performed directly without App Store Connect listing.
4. **Given** a broken release is detected, **When** rollback is needed, **Then** a previously stored signed IPA can be redeployed quickly.
5. **Given** deployment is requested, **When** required review gates are not satisfied, **Then** deployment is blocked using the same mandatory review policy as Aither CI/CD.
6. **Given** deployment is requested, **When** the selected source is not a tag on `main`, **Then** deployment is rejected.
7. **Given** rollback is needed, **When** recent artifacts are checked, **Then** at least the last three successful release artifacts are available for immediate redeployment.
8. **Given** deployment is manually triggered, **When** the actor is not a repository admin, **Then** deployment is denied.

### Edge Cases

- What happens when signing credentials or provisioning profiles are missing, expired, or mismatched?
- What happens when CI passes but deployment packaging fails at signing or export time?
- How is release safety handled when the deployment workflow is triggered from an unverified commit?
- How are secrets rotated without breaking deployment continuity?

## Requirements

### Functional Requirements

- **FR-001**: The process MUST define separate CI and deployment workflows.
- **FR-002**: CI MUST run formatting/lint, build, and automated tests for every pull request and push to the release branch.
- **FR-003**: Deployment MUST be manually triggerable and MUST require a successful CI baseline for a deployment-eligible tagged release commit on `main`.
- **FR-004**: Deployment artifacts MUST include at minimum a signed IPA, build metadata, and symbol files for crash diagnostics.
- **FR-005**: The process MUST support iPad installation without App Store publication.
- **FR-006**: The process MUST define secret handling and rotation expectations for signing credentials and service tokens.
- **FR-007**: The process MUST define rollback steps that do not require rebuilding from scratch.
- **FR-008**: The process MUST define failure handling and operator-visible diagnostics for CI and deployment stages.
- **FR-009**: For the current planning milestone, scope MUST remain limited to design artifacts; implementation tasks MAY be defined but MUST only execute after explicit authorization.
- **FR-010**: The CI/CD definition MUST include all applicable Aither-derived technical quality gates (including build, tests, and formatting/linting equivalents) before deployment eligibility.
- **FR-011**: Gaia MUST require at least one human approval, a passing automated review gate, and zero unresolved blocking comments before deployment eligibility.
- **FR-012**: Deployment sources MUST be restricted to tagged releases on `main`.
- **FR-013**: Deployment-eligible tags MUST follow semantic version format `vMAJOR.MINOR.PATCH`.
- **FR-014**: Rollback readiness MUST retain at least the last three successful release artifact bundles.
- **FR-015**: Manual deployment triggers MUST be restricted to repository admins.
- **FR-016**: CI MUST enforce explicit formatting and linting checks as required gates before merge and before deployment eligibility.

### Non-Functional Requirements

- **NFR-001 (CI feedback latency)**: Standard pull request CI feedback SHOULD be available within 15 minutes.
- **NFR-002 (artifact retention reliability)**: At least the last three successful release artifact bundles MUST remain retrievable at all times.
- **NFR-003 (deployment diagnostics completeness)**: Failed deployment runs MUST emit machine-readable failure categories for precondition, signing, packaging, and publication stages.

### Key Entities

- **PipelineStage**: Represents one stage in CI/CD (e.g., lint, build, test, sign, package, deploy).
- **ReleaseArtifact**: Represents generated outputs (IPA, dSYM/symbols, metadata manifest).
- **SigningBundle**: Represents signing inputs (certificate, provisioning profile, team/app identifiers).
- **DeploymentRun**: Represents one manually triggered deployment attempt with status and logs.
- **RollbackCandidate**: Represents a previously verified artifact eligible for redeployment.

## Review & Acceptance Checklist

### Content Quality

- [x] No implementation details that are irrelevant to user value
- [x] Focused on user value and operational reliability
- [x] Written for repo stakeholders and maintainers
- [x] All mandatory sections completed

### Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified
- [x] Security, observability, and failure-state expectations are captured when relevant

## Execution Status

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed