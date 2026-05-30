# Tasks: CI/CD Process for iPad-Only Distribution

**Input**: Design documents from `specs/006-ci-cd-process/`  
**Prerequisites**: `specs/006-ci-cd-process/plan.md` (required), `specs/006-ci-cd-process/research.md`, `specs/006-ci-cd-process/data-model.md`, `specs/006-ci-cd-process/contracts/workflow-contract.md`, `specs/006-ci-cd-process/quickstart.md`

## Phase 3.1: Setup

- [X] T001 Confirm feature scope and planning-only baseline from `specs/006-ci-cd-process/spec.md`
- [X] T002 Create CI/CD documentation structure in `docs/ops/` with release and rollback runbook placeholders
- [X] T003 [P] Define signing and workflow secret inventory in `docs/ops/ci-cd-secrets.md`
- [X] T004 [P] Define release tagging and governance policy in `docs/ops/release-policy.md` (`main` + `vMAJOR.MINOR.PATCH` + admin trigger)

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests/checks MUST be written and MUST fail before implementation**

### Contract-derived tests

- [X] T005 [P] Add contract test coverage for `specs/006-ci-cd-process/contracts/workflow-contract.md` in `tests/contracts/ci-cd/workflow-contract.spec.ts`

### User story & quickstart integration tests

- [X] T006 [P] Add integration test for PR quality gate scenario in `legacy/ci-cd-ts-tests/pr-quality-gate.spec.ts`
- [X] T007 [P] Add integration test for explicit formatting/linting gate enforcement in `legacy/ci-cd-ts-tests/format-lint-gates.spec.ts`
- [X] T008 [P] Add integration test for manual deploy from semver tag on `main` in `legacy/ci-cd-ts-tests/manual-deploy-semver-main.spec.ts`
- [X] T009 [P] Add integration test for deploy authorization guard (non-admin denied) in `legacy/ci-cd-ts-tests/deploy-authorization.spec.ts`
- [X] T010 [P] Add integration test for invalid source/tag rejection in `legacy/ci-cd-ts-tests/source-tag-validation.spec.ts`
- [X] T011 [P] Add integration test for missing signing input failure behavior in `legacy/ci-cd-ts-tests/signing-precondition-failure.spec.ts`
- [X] T012 [P] Add integration test for direct device-install artifact readiness in `legacy/ci-cd-ts-tests/device-install-artifacts.spec.ts`
- [X] T013 [P] Add integration test for rollback readiness with last 3 successful artifacts in `legacy/ci-cd-ts-tests/rollback-retention.spec.ts`

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Entity/model implementation tasks (from data-model.md)

- [X] T014 [P] Implement `PipelineStage` model and transition rules in `Sources/GaiaCore/CICD/PipelineStage.swift`
- [X] T015 [P] Implement `ReviewGatePolicy` model and validation rules in `Sources/GaiaCore/CICD/ReviewGatePolicy.swift`
- [X] T016 [P] Implement `SigningBundle` model and expiration checks in `Sources/GaiaCore/CICD/SigningBundle.swift`
- [X] T017 [P] Implement `ReleaseArtifact` model including semver tag validation in `Sources/GaiaCore/CICD/ReleaseArtifact.swift`
- [X] T018 [P] Implement `DeploymentRun` model including admin/main/tag constraints in `Sources/GaiaCore/CICD/DeploymentRun.swift`
- [X] T019 [P] Implement `RollbackCandidate` model including retention-rank semantics in `Sources/GaiaCore/CICD/RollbackCandidate.swift`

### Core workflow/services

- [X] T020 Implement CI gate evaluator service (lint/build/test + Aither-applicable review gates) in `Sources/GaiaCore/CICD/CIGateEvaluator.swift`
- [X] T021 Implement explicit formatting/linting gate mapping in `Sources/GaiaCore/CICD/CIGateEvaluator.swift`
- [X] T022 Implement deployment eligibility service (CI success + admin + semver tag on main) in `Sources/GaiaCore/CICD/DeploymentEligibilityService.swift`
- [X] T023 Implement release artifact retention service (keep latest 3 successful bundles) in `Sources/GaiaCore/CICD/ArtifactRetentionService.swift`
- [X] T024 Implement release metadata generation service in `Sources/GaiaCore/CICD/ReleaseMetadataService.swift`

### Workflow definitions and endpoint-like entry surfaces

- [X] T025 Implement CI workflow in `.github/workflows/ci.yml`
- [X] T026 Implement manual deploy workflow in `.github/workflows/deploy-ipad.yml`
- [X] T027 Implement workflow preflight diagnostics mapping in `scripts/ci-cd/preflight-check.sh`

## Phase 3.4: Integration

- [X] T028 Integrate workflow contracts with quality gates documentation in `docs/ops/ci-cd-quality-gates.md`
- [X] T029 Integrate rollback runbook with artifact retention and selection flow in `docs/ops/rollback-runbook.md`
- [X] T030 Integrate release runbook for admin-triggered semver-tag deployment in `docs/ops/release-runbook.md`
- [X] T031 Integrate symbol publication guidance for crash observability in `docs/ops/crash-symbols.md`

## Phase 3.5: Polish

- [X] T032 [P] Add regression tests for edge cases (expired profile, missing secret, unresolved review gate) in `legacy/ci-cd-ts-tests/edge-cases.spec.ts`
- [X] T033 [P] Add performance check for CI feedback target in `legacy/ci-cd-ts-tests/ci-feedback-time.spec.ts`
- [X] T034 [P] Update operator-facing summary in `README.md`
- [X] T035 Verify all quickstart scenarios in `specs/006-ci-cd-process/quickstart.md` against implemented behavior and record outcomes in `docs/ops/ci-cd-validation-report.md`
- [X] T036 Run final verification (`swift format lint`, `swift build`, `swift test`, workflow lint checks) and attach outputs to `docs/ops/ci-cd-validation-report.md`

## Dependencies

- T001-T004 before all test and implementation work.
- T005-T013 before T014-T027 (TDD gate).
- T014-T019 before T020-T024.
- T020-T024 before T025-T027.
- T025-T027 before T028-T031.
- T028-T031 before T032-T036.

## Parallel Execution Examples

```text
# Parallel contract + scenario tests
Task: "T005 Add contract test coverage in tests/contracts/ci-cd/workflow-contract.spec.ts"
Task: "T006 Add PR quality gate integration test"
Task: "T007 Add format/lint gate integration test"
Task: "T008 Add manual deploy semver-main integration test"
Task: "T009 Add deploy authorization integration test"
Task: "T010 Add source/tag validation integration test"
Task: "T011 Add signing precondition failure integration test"
Task: "T012 Add device-install artifacts integration test"
Task: "T013 Add rollback retention integration test"

# Parallel entity model implementation
Task: "T014 Implement PipelineStage model"
Task: "T015 Implement ReviewGatePolicy model"
Task: "T016 Implement SigningBundle model"
Task: "T017 Implement ReleaseArtifact model"
Task: "T018 Implement DeploymentRun model"
Task: "T019 Implement RollbackCandidate model"
```

## Validation Checklist

- [X] All contracts have corresponding tests
- [X] All entities from data-model have model tasks
- [X] All user scenarios/quickstart flows have integration tests
- [X] Formatting and linting gates are explicitly covered by tests and final verification
- [X] Tests are ordered before implementation
- [X] Parallel tasks target independent files
- [X] Every task includes an absolute file path

## Current State

Implementation artifacts were created and validated according to this task plan.
