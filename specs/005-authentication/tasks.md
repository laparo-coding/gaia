# Tasks: Authentication

**Input**: Design documents from `specs/005-authentication/`
**Prerequisites**: `specs/005-authentication/plan.md`, `specs/005-authentication/research.md`, `specs/005-authentication/data-model.md`, `specs/005-authentication/contracts/openapi.yaml`, `specs/005-authentication/quickstart.md`

## Phase 3.1: Setup

- [x] T001 Confirm scope and target paths from `specs/005-authentication/plan.md`
- [x] T002 Create the feature folders `Sources/GaiaCore/Authentication/` and `Tests/GaiaCoreTests/Authentication/`
- [x] T003 Create shared auth fixtures in `Tests/GaiaCoreTests/Authentication/AuthTestSupport.swift`

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

- [x] T004 [P] Add the contract test for `specs/005-authentication/contracts/openapi.yaml` in `Tests/GaiaCoreTests/Authentication/AuthenticationContractsTests.swift`
- [x] T005 [P] Add `UserSession` model and state-transition tests in `Tests/GaiaCoreTests/Authentication/UserSessionTests.swift`
- [x] T006 [P] Add `AuthCredentials` and `AuthorizationRule` validation tests in `Tests/GaiaCoreTests/Authentication/AuthorizationRuleTests.swift`
- [x] T007 [P] Add `ServiceCredential` and `ServiceTokenCache` tests in `Tests/GaiaCoreTests/Authentication/ServiceTokenCacheTests.swift`
- [x] T008 [P] Add the interactive sign-in scenario from quickstart scenario 1 in `Tests/GaiaCoreTests/Authentication/InteractiveSignInScenarioTests.swift`
- [x] T009 [P] Add the interactive auth failure scenario from quickstart scenario 2 in `Tests/GaiaCoreTests/Authentication/InteractiveFailureScenarioTests.swift`
- [x] T010 [P] Add the Hemera service-auth caching scenario from quickstart scenario 3 in `Tests/GaiaCoreTests/Authentication/HemeraServiceAuthorizationScenarioTests.swift`
- [x] T011 [P] Add the Aither service-auth separation scenario from quickstart scenario 4 in `Tests/GaiaCoreTests/Authentication/AitherServiceAuthorizationScenarioTests.swift`
- [x] T012 [P] Add the retry-on-expiry scenario from quickstart scenario 5 in `Tests/GaiaCoreTests/Authentication/ServiceRetryOnExpiryScenarioTests.swift`

## Phase 3.3: Core Models and Services (ONLY after tests are failing)

- [x] T013 [P] Implement `UserSession` in `Sources/GaiaCore/Authentication/UserSession.swift`
- [x] T014 [P] Implement `AuthCredentials` and `AuthorizationRule` in `Sources/GaiaCore/Authentication/AuthorizationRule.swift`
- [x] T015 [P] Implement `ServiceCredential` and `ServiceTokenCache` in `Sources/GaiaCore/Authentication/ServiceCredential.swift`
- [x] T016 Implement the interactive auth state machine and destination restore logic in `Sources/GaiaCore/Authentication/AuthenticationSessionManager.swift`
- [x] T017 Implement the shared Bearer token cache and expiry logic in `Sources/GaiaCore/Authentication/ServiceTokenCacheStore.swift`
- [x] T018 Implement Hemera service authorization using a shared service credential that is emitted on the wire as `X-API-Key` in `Sources/GaiaCore/Authentication/HemeraServiceAuthenticator.swift`
- [x] T019 Implement Aither service authorization with a separate audience, credential path, and `Authorization: Bearer` downstream header contract in `Sources/GaiaCore/Authentication/AitherServiceAuthenticator.swift`
- [x] T020 Implement single-refresh retry-on-expiry orchestration for both downstream targets in `Sources/GaiaCore/Authentication/ServiceAuthorizationCoordinator.swift`

## Phase 3.4: Contract and UI Integration

- [x] T021 Implement the `/api/auth/session` GET and DELETE contract surface in `app/authentication/session/route.swift`
- [x] T022 Implement the `/api/auth/sign-in` POST contract surface in `app/authentication/sign-in/route.swift`
- [x] T023 Implement the internal Hemera service-authorization endpoint for `/api/auth/service/hemera/authorize` in `app/authentication/service/hemera/route.swift`
- [x] T024 Implement the internal Aither service-authorization endpoint for `/api/auth/service/aither/authorize` in `app/authentication/service/aither/route.swift`
- [x] T025 Implement the first protected authentication shell and degraded-state UI in `app/authentication/page.swift`
- [x] T026 Implement request-scoped logging, secret-safe error mapping, and auth failure observability in `Sources/GaiaCore/Authentication/AuthenticationTelemetry.swift`

## Phase 3.5: Polish

- [x] T027 [P] Update contributor documentation in `README.md` and `Documentation.docc/gaia.md`
- [x] T028 Run `swift build` and `swift format lint --configuration .swift-format --strict Package.swift && swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication`
- [x] T029 Run targeted auth tests for `Tests/GaiaCoreTests/Authentication/` with a full Xcode toolchain
- [x] T030 Execute the scenarios in `specs/005-authentication/quickstart.md` and record gaps

## Dependencies

- T002-T003 before all test and implementation tasks
- T004-T012 before T013-T026
- T013-T015 before T016-T020
- T017 blocks T018-T020
- T018 and T019 block T020, T023, and T024
- T016 and T020 block T021-T025
- T021-T026 before T027-T030

## Parallel Execution Examples

```text
# Parallel test batch after setup
Task: "T004 Contract test in Tests/GaiaCoreTests/Authentication/AuthenticationContractsTests.swift"
Task: "T005 UserSession tests in Tests/GaiaCoreTests/Authentication/UserSessionTests.swift"
Task: "T006 AuthorizationRule tests in Tests/GaiaCoreTests/Authentication/AuthorizationRuleTests.swift"
Task: "T007 ServiceTokenCache tests in Tests/GaiaCoreTests/Authentication/ServiceTokenCacheTests.swift"

# Parallel scenario batch after setup
Task: "T008 Interactive sign-in scenario in Tests/GaiaCoreTests/Authentication/InteractiveSignInScenarioTests.swift"
Task: "T009 Interactive failure scenario in Tests/GaiaCoreTests/Authentication/InteractiveFailureScenarioTests.swift"
Task: "T010 Hemera service-auth scenario in Tests/GaiaCoreTests/Authentication/HemeraServiceAuthorizationScenarioTests.swift"
Task: "T011 Aither service-auth scenario in Tests/GaiaCoreTests/Authentication/AitherServiceAuthorizationScenarioTests.swift"
Task: "T012 Retry-on-expiry scenario in Tests/GaiaCoreTests/Authentication/ServiceRetryOnExpiryScenarioTests.swift"

# Parallel model batch after tests fail
Task: "T013 UserSession model in Sources/GaiaCore/Authentication/UserSession.swift"
Task: "T014 Authorization types in Sources/GaiaCore/Authentication/AuthorizationRule.swift"
Task: "T015 Service credential models in Sources/GaiaCore/Authentication/ServiceCredential.swift"
```

## Validation Checklist

- [x] All contracts have corresponding tests
- [x] All entities have model tasks
- [x] All tests come before implementation
- [x] Parallel tasks use different files
- [x] Each task specifies an exact file path
- [x] Endpoint tasks exist for all OpenAPI paths

## Validation Notes

- Feature scaffold created through the live Gaia CLI.
- Product spec, plan, and tasks completed before any implementation work.
- Local `swift test` execution now succeeds with the active Xcode toolchain.
- Quickstart scenarios 1-5 are covered by the green authentication test suite under `Tests/GaiaCoreTests/Authentication/`.
- The `app/authentication/` surface is now executable through `swift run GaiaAuthenticationApp --port 8080` for local HTTP validation.
- Gaia now includes a real downstream client in `GaiaCore` and a reproducible live integration check through `swift run GaiaCLI service-check` for Hemera (`X-API-Key`) and Aither (`Authorization: Bearer`).