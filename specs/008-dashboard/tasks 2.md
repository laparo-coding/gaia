# Tasks: Dashboard

**Input**: Design documents from `/specs/008-dashboard/`
**Prerequisites**: plan.md, spec.md

## Phase 1: Setup

- [X] T001 Create dashboard module folders in `Sources/GaiaCore/Dashboard/` and `Tests/GaiaCoreTests/Dashboard/`
- [X] T002 Create design token namespace file in `Sources/GaiaCore/Design/DashboardDesignTokens.swift`
- [X] T003 [P] Add dashboard task filter entries to `.vscode/tasks.json` for focused `swift test --filter Dashboard`
- [X] T004 [P] Document Aither visual extraction notes for dashboard in `specs/008-dashboard/plan.md`

## Phase 2: Foundational (Blocking Prerequisites)

- [X] T005 Implement shared dashboard state and card-state models in `Sources/GaiaCore/Dashboard/DashboardState.swift`
- [X] T006 Implement TTL cache primitives (fresh/stale/expired) in `Sources/GaiaCore/Dashboard/DashboardCache.swift`
- [X] T007 Implement dashboard service protocol surfaces in `Sources/GaiaCore/Dashboard/DashboardServiceProtocol.swift`
- [X] T008 Implement SSE event message decoding models in `Sources/GaiaCore/Dashboard/DashboardStatusEvent.swift`
- [X] T009 Add dashboard configuration keys (TTL window, SSE endpoint) in `Sources/GaiaCore/Configuration/LocalEnvironment.swift`
- [X] T009A Finalize SSE endpoint ownership and payload responsibility notes in `specs/008-dashboard/research.md`
- [X] T009B Normalize `GAIA_DASHBOARD_SSE_ENDPOINT` (leading slash, URL parsing, default fallback) in `Sources/GaiaCore/Configuration/LocalEnvironment.swift` and add coverage in `Tests/GaiaCoreTests/LocalEnvironmentTests.swift`
- [X] T009C Disable controller red-phase placeholder suites (`Tests/GaiaCoreTests/Controller/*`) and harden dashboard test protocol via `ScopedDashboardURLProtocol` in `Tests/GaiaCoreTests/Dashboard/DashboardURLProtocol.swift`
- [X] T009D Fix SSE connection lifecycle to ensure cleanup on all exit paths and validate chunked encoding (server pump + client stream)
	- Add `Sources/GaiaCore/Dashboard/HTTPChunkedTransfer.swift` with encoder/decoder + tests in `Tests/GaiaCoreTests/Dashboard/HTTPChunkedTransferTests.swift`
	- Refactor `pumpStatusEventStream` in `app/authentication/main.swift` to use `HTTPChunkedTransfer`, deterministic `defer` cleanup, double-cancel guard, and filter benign POSIX 57/32 errors
	- Replace `AsyncStream { continuation in }` body in `app/authentication/DashboardRouteHandlers.swift` with `AsyncStream<String>.makeStream()` and heartbeat-finish on termination
	- Add lifecycle tests in `Tests/GaiaCoreTests/Dashboard/ConnectionStatusMonitorTests.swift` (clean stream end, bounded reconnect error, cancellation)

## Phase 3: User Story 1 - Dashboard shell, launch path, and role-gated seminar action (Priority: P1)

**Goal**: Dashboard appears as first usable controller view with header action `Seminar starten` role-gated for authorized users.

**Independent Test Criteria**: On app launch, dashboard root is visible in iPad landscape; unauthorized session cannot trigger seminar start; authorized session can navigate into presentation flow.

- [X] T010 [P] [US1] Add failing role-gate unit tests for seminar start policy in `Tests/GaiaCoreTests/Dashboard/SeminarStartAuthorizationTests.swift`
- [X] T011 [P] [US1] Add failing controller launch scenario test for dashboard-first rendering in `Tests/GaiaCoreTests/Controller/ControllerInitialLoadScenarioTests.swift`
- [X] T012 [US1] Implement seminar start authorization policy using `UserSession.role` in `Sources/GaiaCore/Dashboard/SeminarStartPolicy.swift`
- [X] T013 [US1] Implement dashboard root view model shell and launch state in `app/controller/DashboardViewModel.swift`
- [X] T014 [US1] Implement dashboard root layout and header action placement in `app/controller/DashboardRootView.swift`
- [X] T015 [US1] Wire dashboard as default controller entry view in `app/controller/ControllerRootView.swift`
- [X] T016 [US1] Wire authorized seminar start navigation to existing presentation flow in `app/controller/ControllerViewModel.swift`

## Phase 4: User Story 2 - Connection monitor with SSE push updates and soft-fail behavior (Priority: P1)

**Goal**: Connection monitor card shows Aither/Hemera states via SSE updates without polling; partial failures affect only impacted card.

**Independent Test Criteria**: SSE events update connection card states in real time; when SSE or one service fails, only connection card shows error while other cards remain usable.

- [X] T017 [P] [US2] Add failing SSE event stream tests for connection state transitions in `Tests/GaiaCoreTests/Dashboard/ConnectionStatusMonitorTests.swift`
- [X] T018 [P] [US2] Add failing soft-fail scenario test for card-level degradation in `Tests/GaiaCoreTests/Dashboard/DashboardSoftFailScenarioTests.swift`
- [X] T019 [US2] Implement SSE connection monitor with reconnect/backoff in `Sources/GaiaCore/Dashboard/ConnectionStatusMonitor.swift`
- [X] T020 [US2] Implement connection monitor card UI (connected/disconnected/connecting) in `app/controller/ConnectionMonitorCard.swift`
- [X] T021 [US2] Integrate connection monitor card state mapping in `app/controller/DashboardViewModel.swift`
- [X] T022 [US2] Add dashboard status endpoint handler for connection feed bootstrap in `app/authentication/DashboardRouteHandlers.swift`
- [X] T022A [US2] Add SSE events stream route handler for `/api/dashboard/status/events` in `app/authentication/DashboardRouteHandlers.swift`

## Phase 5: User Story 3 - Participant overview from Hemera with short-lived cache and stale warning (Priority: P1)

**Goal**: Participant names and avatars are loaded from Hemera, cached with 30-60s TTL, and stale fallback warning is shown when Hemera is unavailable.

**Independent Test Criteria**: Initial participant fetch succeeds; cache revalidates after TTL; on Hemera outage last valid data is displayed with visible `Daten evtl. veraltet` warning.

- [X] T023 [P] [US3] Add failing cache lifecycle tests (fresh/stale/expired) in `Tests/GaiaCoreTests/Dashboard/DashboardCacheTests.swift`
- [X] T024 [P] [US3] Add failing Hemera fallback tests for stale warning behavior in `Tests/GaiaCoreTests/Dashboard/ParticipantFallbackTests.swift`
- [X] T025 [US3] Implement Hemera participant/course client with auth integration in `Sources/GaiaCore/Dashboard/HemeraDashboardClient.swift`
- [X] T026 [US3] Implement dashboard data orchestration with cache revalidation in `Sources/GaiaCore/Dashboard/DashboardService.swift`
- [X] T027 [US3] Implement participant overview card UI with avatar/name grid in `app/controller/ParticipantOverviewCard.swift`
- [X] T028 [US3] Integrate participant data loading and stale warning state in `app/controller/DashboardViewModel.swift`
- [X] T029 [US3] Add dashboard participants/course route handlers in `app/authentication/DashboardRouteHandlers.swift`

## Phase 6: User Story 4 - System status card with minimal health metrics and version visibility (Priority: P2)

**Goal**: System status card shows minimal metrics (version, service status, last update) consistent with dashboard token styling.

**Independent Test Criteria**: System status card renders required minimal metrics and updates from backend/status providers without blocking other cards.

- [X] T030 [P] [US4] Add failing unit tests for minimal system metrics mapping in `Tests/GaiaCoreTests/Dashboard/SystemStatusMetricsTests.swift`
- [X] T031 [US4] Implement system health provider for version/status/last-update in `Sources/GaiaCore/Dashboard/SystemHealthService.swift`
- [X] T032 [US4] Implement system status card UI with tokenized styling in `app/controller/SystemStatusCard.swift`
- [X] T033 [US4] Integrate system status card state updates in `app/controller/DashboardViewModel.swift`
- [X] T034 [US4] Add system status route handler in `app/authentication/DashboardRouteHandlers.swift`

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T035 [P] Apply final dashboard token values (color/typography/spacing/elevation/radius) in `Sources/GaiaCore/Design/DashboardDesignTokens.swift`
- [X] T036 Validate iPad landscape layout and launch behavior with `scripts/ci-cd/validate-controller-ipad-build.sh`
- [X] T037 Validate first usable dashboard render <=2.0s using `scripts/ci-cd/measure-controller-performance.sh`
- [X] T038 [P] Add dashboard implementation and operations notes in `docs/ops/ci-cd-validation-report.md`
- [X] T039 Run quality gates (`swift build`, targeted `swift test --filter Dashboard`, Codacy standard check) and record outputs in `specs/008-dashboard/plan.md`
- [X] T040 Add a no-third-party-UI guard checklist in `specs/008-dashboard/plan.md` that verifies `Package.swift` and dashboard imports do not introduce external UI libraries
- [X] T041 Validate responsive behavior explicitly for iPad landscape 11-inch and 13-inch in `docs/ops/ci-cd-validation-report.md`

## Dependencies

- Setup (Phase 1) must complete before Foundational (Phase 2).
- Foundational (Phase 2) blocks all user stories.
- User Story order: US1 -> US2 -> US3 -> US4.
- US2 depends on US1 launch/view-model shell.
- US3 depends on Phase 2 cache and service protocol definitions.
- US4 depends on US1 shell and Phase 2 status models.
- Polish phase starts after selected user stories are complete.

## Parallel Execution Examples

### User Story 1

- Run T010 and T011 in parallel (different test files).

### User Story 2

- Run T017 and T018 in parallel before implementation.

### User Story 3

- Run T023 and T024 in parallel before implementation.

### User Story 4

- Run T030 in parallel with remaining open tasks from US3 if ownership is split.

## Implementation Strategy

### MVP First (US1 + US2 + US3)

- Deliver dashboard-first launch, seminar role-gate, SSE connection monitor, participant fetch/cache/revalidation, and stale fallback warning.
- Validate functional acceptance and performance target before extending to US4.

### Incremental Delivery

- Increment 1: Complete US1 and verify launch + role-gated navigation.
- Increment 2: Complete US2 and verify SSE real-time connection updates with soft-fail behavior.
- Increment 3: Complete US3 and verify Hemera cache/revalidation + stale warning fallback.
- Increment 4: Complete US4 and polish cross-cutting quality gates.

## Format Validation

- All tasks use required checklist format: `- [ ] Txxx [P?] [USx?] Description with file path`.
- Story labels are present for all user-story tasks and absent for setup/foundational/polish tasks.
- Parallel markers are only used for tasks intended to be independent.
