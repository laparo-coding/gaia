# Tasks: Controller Design

**Input**: Design documents from `specs/007-controller-design/`
**Prerequisites**: `specs/007-controller-design/plan.md`, `specs/007-controller-design/research.md`, `specs/007-controller-design/data-model.md`, `specs/007-controller-design/contracts/controller-api.md`, `specs/007-controller-design/quickstart.md`

## Phase 3.1: Setup

- [X] T001 Confirm scope and target paths from `specs/007-controller-design/plan.md`
- [X] T002 Create the feature folders `Sources/GaiaCore/Controller/`, `Tests/GaiaCoreTests/Controller/`, `app/controller/`, and `app/controller-bridge/`
- [X] T003 Create shared controller fixtures in `Tests/GaiaCoreTests/Controller/ControllerTestSupport.swift`
- [X] T003A Create or wire a concrete iPad app target scaffold for `app/controller/` and document reproducible build steps.
- [X] T003B Add a validation task proving the iPad controller app target builds for iPad landscape configuration.

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

- [X] T004 [P] Add the contract test for `specs/007-controller-design/contracts/controller-api.md` in `Tests/GaiaCoreTests/Controller/ControllerContractTests.swift`
- [X] T005 [P] Add `ControllerSession` and `ControllerManifest` model tests in `Tests/GaiaCoreTests/Controller/ControllerSessionTests.swift`
- [X] T006 [P] Add `ControllerSlide`, `NavigationCommand`, and layout invariant tests in `Tests/GaiaCoreTests/Controller/ControllerNavigationStateTests.swift`
- [X] T007 [P] Add Aither controller manifest client and placeholder-notes fallback tests in `Tests/GaiaCoreTests/Controller/AitherControllerClientTests.swift`
- [X] T008 [P] Add Gaia bridge presentation and navigation route tests in `Tests/GaiaCoreTests/Controller/ControllerBridgeRouteTests.swift`
- [X] T009 [P] Add the initial-load scenario from quickstart scenario 1 in `Tests/GaiaCoreTests/Controller/ControllerInitialLoadScenarioTests.swift`
- [X] T010 [P] Add the forward/back synchronization scenario from quickstart scenario 2 in `Tests/GaiaCoreTests/Controller/ControllerNavigationScenarioTests.swift`
- [X] T011 [P] Add the notes overflow scenario from quickstart scenario 3 in `Tests/GaiaCoreTests/Controller/ControllerNotesOverflowScenarioTests.swift`
- [X] T012 [P] Add the loading and failure-state scenario from quickstart scenario 4 in `Tests/GaiaCoreTests/Controller/ControllerErrorStateScenarioTests.swift`
- [X] T013 [P] Add the button-only input policy scenario from quickstart scenario 5 in `Tests/GaiaCoreTests/Controller/ControllerInputPolicyScenarioTests.swift`
- [X] T014 [P] Add the placeholder-notes scenario from quickstart scenario 6 in `Tests/GaiaCoreTests/Controller/ControllerPlaceholderNotesScenarioTests.swift`

## Phase 3.3: Core Models and Services (ONLY after tests are failing)

- [X] T015 [P] Implement `ControllerSession` and `ControllerManifest` in `Sources/GaiaCore/Controller/ControllerSession.swift`
- [X] T016 [P] Implement `ControllerSlide`, `NavigationCommand`, layout invariants, and notes-source tracking in `Sources/GaiaCore/Controller/ControllerSlide.swift`
- [X] T017 Implement the upstream Aither controller manifest client plus placeholder-notes fallback in `Sources/GaiaCore/Controller/AitherControllerClient.swift`
- [X] T018 Implement bridge orchestration, adjacent-slide prefetching, and active-slide synchronization in `Sources/GaiaCore/Controller/ControllerBridgeService.swift`
- [X] T019 Implement secret-safe controller telemetry and error mapping in `Sources/GaiaCore/Controller/ControllerTelemetry.swift`

## Phase 3.4: Bridge and iPad App Integration

- [X] T020 Implement the Gaia bridge presentation route in `app/controller-bridge/presentation/route.swift`
- [X] T021 Implement the Gaia bridge navigation route in `app/controller-bridge/navigation/route.swift`
- [X] T022 Implement the controller iPad app entry point and scene setup in `app/controller/GaiaControllerApp.swift`
- [X] T023 Implement the root split layout and button bar in `app/controller/ControllerRootView.swift`
- [X] T024 Implement the WebKit slide viewport wrapper in `app/controller/SlideViewportView.swift`
- [X] T025 Implement the independently scrollable notes panel with identifiable placeholder rendering in `app/controller/SlideNotesView.swift`
- [X] T026 Implement the controller view model and bridge-facing client in `app/controller/ControllerViewModel.swift`
- [X] T027 Implement loading and inline error overlays in `app/controller/ControllerStatusOverlay.swift`

## Phase 3.5: Polish

- [X] T028 [P] Update contributor documentation in `README.md` and `Documentation.docc/gaia.md`
- [X] T029 Add or update VS Code tasks and launch configuration for controller build/test validation in `.vscode/tasks.json` and `.vscode/launch.json`
- [X] T029A Validate required external Aither controller endpoints are available per `specs/007-controller-design/contracts/controller-api.md` (no Aither code changes in this feature).
- [X] T029B Validate performance targets from `specs/007-controller-design/plan.md` on iPad landscape (initial payload + first slide <= 2.0 s, previous/next response <= 150 ms for prefetched adjacent slides) and document results in `specs/007-controller-design/quickstart.md`.
	- Executed via `BASE_URL=http://127.0.0.1:8099 COURSE_ID=course-123 ITERATIONS=10 OUT_FILE=specs/007-controller-design/performance-results.md ./scripts/ci-cd/measure-controller-performance.sh`; results documented in quickstart and report file.
	- Live run also validated via `GAIA_AITHER_BASE_URL=http://127.0.0.1:3001 AITHER_SYNC_TOKEN=local-dev-token swift run GaiaAuthenticationApp --port 8080` and `BASE_URL=http://127.0.0.1:8080 COURSE_ID=course-123 ITERATIONS=10 OUT_FILE=specs/007-controller-design/performance-results-live.md ./scripts/ci-cd/measure-controller-performance.sh`.
- [X] T030 Run `swift build`, the repository format/lint commands plus any controller-target-specific additions, and targeted controller tests under `Tests/GaiaCoreTests/Controller/`
- [X] T031 Execute the scenarios in `specs/007-controller-design/quickstart.md` and record any gaps

## Dependencies

- T002-T003 before all test and implementation tasks
- T003A-T003B before T022-T027
- T004-T014 before T015-T027
- T015-T016 before T017-T019
- T017 blocks T018, T020, and T021
- T018 blocks T020, T021, and T026
- T020-T021 before T022-T027
- T022-T027 before T028-T031
- T029A before T031
- T029B before T031

## Parallel Execution Examples

```text
# Parallel model and contract tests after setup
Task: "T004 Contract test in Tests/GaiaCoreTests/Controller/ControllerContractTests.swift"
Task: "T005 ControllerSession tests in Tests/GaiaCoreTests/Controller/ControllerSessionTests.swift"
Task: "T006 Navigation state tests in Tests/GaiaCoreTests/Controller/ControllerNavigationStateTests.swift"
Task: "T007 Aither controller client and placeholder fallback tests in Tests/GaiaCoreTests/Controller/AitherControllerClientTests.swift"

# Parallel scenario test batch after setup
Task: "T009 Initial load scenario in Tests/GaiaCoreTests/Controller/ControllerInitialLoadScenarioTests.swift"
Task: "T010 Navigation scenario in Tests/GaiaCoreTests/Controller/ControllerNavigationScenarioTests.swift"
Task: "T011 Notes overflow scenario in Tests/GaiaCoreTests/Controller/ControllerNotesOverflowScenarioTests.swift"
Task: "T012 Error-state scenario in Tests/GaiaCoreTests/Controller/ControllerErrorStateScenarioTests.swift"
Task: "T013 Input policy scenario in Tests/GaiaCoreTests/Controller/ControllerInputPolicyScenarioTests.swift"
Task: "T014 Placeholder-notes scenario in Tests/GaiaCoreTests/Controller/ControllerPlaceholderNotesScenarioTests.swift"

# Parallel shared model implementation after tests fail
Task: "T015 ControllerSession models in Sources/GaiaCore/Controller/ControllerSession.swift"
Task: "T016 ControllerSlide and NavigationCommand in Sources/GaiaCore/Controller/ControllerSlide.swift"
Task: "T019 Controller telemetry in Sources/GaiaCore/Controller/ControllerTelemetry.swift"
```

## Validation Checklist

- [x] All contracts have corresponding tests
- [x] All entities have model tasks
- [x] All tests come before implementation
- [x] Parallel tasks use different files
- [x] Each task specifies an exact file path
- [x] Bridge and client tasks exist for all defined controller surfaces