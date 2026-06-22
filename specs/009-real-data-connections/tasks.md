# Tasks: Real Data Connections

**Input**: Design documents from `/specs/009-real-data-connections/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/dashboard-api.md, quickstart.md

## Execution Flow Summary

- **Feature**: Connect the Gaia dashboard to real Hemera data, remove the
  `DashboardSnapshot.demo(...)` runtime fallback, route traffic through the
  Spec 005 auth stack (`X-API-Key` for Hemera, `Authorization: Bearer` for
  Aither triggers), make base URLs configurable per environment, and preserve
  Spec 008 UX (soft-fail per card, short-lived cache + revalidation, SSE status,
  "Daten evtl. veraltet" warning).
- **Stack**: Swift 6.x, SwiftPM, Foundation `URLSession`, existing `GaiaCore`
  modules (`Authentication`, `Dashboard`, `Configuration`).
- **TDD order**: Contract + integration tests authored first (must fail), then
  implementation, then polish/validation.

## Format: `[ID] [P?] Description`

- **[P]**: Can run in parallel (different files, no dependencies).
- Each task lists the exact file path it touches.

## Path Conventions

- Source: `Sources/GaiaCore/{Authentication,Configuration,Dashboard}/`
- Tests: `Tests/GaiaCoreTests/`, `Tests/contracts/`, `Tests/integration/`

---

## Phase 3.1: Setup

- [x] **T001** Verified the baseline builds and the dashboard tests pass before
  changes (`swift build`, `swift test --filter Dashboard`).
- [x] **T002** [P] Confirmed `quickstart.md` env keys (`GAIA_HEMERA_BASE_URL`,
  `GAIA_AITHER_BASE_URL`) match the new `LocalEnvironment` keys; credential keys
  follow the Spec 005 env/secrets convention.

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation.**

> **Path note**: The repository wires Swift tests through the `GaiaCoreTests`
> target (the top-level `Tests/contracts/` and `Tests/integration/` folders hold
> CI scripts, not SwiftPM targets). Following the established convention, the
> dashboard contract/integration tests live under
> `Tests/GaiaCoreTests/Dashboard/`.

### Contract tests (from `contracts/dashboard-api.md`)

- [x] **T003** [P] Contract test: Hemera requests include `X-API-Key` header, in
  `Tests/GaiaCoreTests/Dashboard/HemeraDashboardAuthContractTests.swift`.
- [x] **T004** [P] Contract test: 200 payloads for `participants`, `status`, and
  `system-health` map correctly to `DashboardSnapshot` fields per the
  Hemera→entity mapping table, in
  `Tests/GaiaCoreTests/Dashboard/HemeraDashboardAuthContractTests.swift`.
- [x] **T005** [P] Contract test: a `401` from Hemera triggers exactly one
  credential refresh + one retry (Spec 005 FR-012), in
  `Tests/GaiaCoreTests/Dashboard/HemeraDashboardRetryContractTests.swift`.
- [x] **T006** [P] Contract test: failure with usable cache returns a stale
  snapshot with the warning; failure without cache yields a structured degraded
  snapshot (no demo data), in
  `Tests/GaiaCoreTests/Dashboard/DashboardSoftFailScenarioTests.swift` +
  `ParticipantFallbackTests.swift`.
- [x] **T006a** [P] Contract test (FR-004): the Aither slide/presentation trigger
  request includes `Authorization: Bearer` and routes through the Spec 005 auth
  transport, in `Tests/GaiaCoreTests/Dashboard/AitherTriggerAuthContractTests.swift`.

### Integration tests (from spec Acceptance Scenarios)

- [x] **T007** [P] Integration (Scenario 1 + FR-006): dashboard loads real
  course/participants/status from Hemera with valid credentials and asserts real
  data on **all three data-bearing cards** — Connection Monitor, Participant
  Overview, and System Status — with **no** "Alex Example/Mara Muster/Sam Sample"
  placeholders, in `Tests/GaiaCoreTests/Dashboard/RealDataDashboardServiceTests.swift`.
- [x] **T008** [P] Integration: `DashboardSnapshot.demo(...)` is **not** served
  on the production fetch path of `loadSnapshot` (Scenario 2), in
  `Tests/GaiaCoreTests/Dashboard/ParticipantFallbackTests.swift`.
- [x] **T009** [P] Integration: Hemera `401` → refresh once + retry once
  (Scenario 3), in `Tests/GaiaCoreTests/Dashboard/HemeraDashboardRetryContractTests.swift`.
- [x] **T010** [P] Integration: Hemera unavailable with warm cache → last cached
  snapshot shown, marked stale with "Daten evtl. veraltet", only affected card
  degrades (Scenario 4), in
  `Tests/GaiaCoreTests/Dashboard/HemeraStaleCacheSoftFailTests.swift`.
- [x] **T011** [P] Integration: unset `GAIA_HEMERA_BASE_URL` → explicit failure,
  no demo data served (quickstart Scenario 5; FR-009/FR-010), in
  `Tests/GaiaCoreTests/Dashboard/RealDataDashboardServiceTests.swift`.

### Configuration unit test

- [x] **T012** [P] Unit test: `LocalEnvironment` resolves per-service base URLs
  (`GAIA_HEMERA_BASE_URL`, `GAIA_AITHER_BASE_URL`) and throws a structured error
  when a required value is missing, in
  `Tests/GaiaCoreTests/LocalEnvironmentServiceURLTests.swift`.

## Phase 3.3: Core Implementation (ONLY after T003–T012 are failing)

### Configuration

- [x] **T013** Extended `Sources/GaiaCore/Configuration/LocalEnvironment.swift`
  with per-service base URL keys (`GAIA_HEMERA_BASE_URL`, `GAIA_AITHER_BASE_URL`),
  a `ConfigurationError`, and `serviceBaseURL(_:in:)` with explicit-failure
  resolution + `http(s)` scheme/host validation for missing/invalid values.

### Auth-backed transport

- [x] **T014** Modified `Sources/GaiaCore/Dashboard/HemeraDashboardClient.swift`
  to accept an injected `@Sendable Transport`; added the `authenticated(...)`
  factory backed by `DownstreamServiceClient` (attaches `X-API-Key`). Kept the
  `URLSession` seam as the default transport for the existing in-memory tests.
- [x] **T015** Verified the one-retry-on-`401` path in
  `DownstreamServiceClient`/`ServiceAuthorizationCoordinator` is reusable as-is
  by the Hemera transport; no duplication of token caching/refresh introduced.

### Remove demo fallback (Constitution VI; FR-001/FR-002)

- [x] **T016** Removed the `DashboardSnapshot.demo(...)` fallback from the live
  fetch path in `HemeraDashboardClient.loadSnapshot`; replaced with
  stale-cache-or-`DashboardSnapshot.degraded(...)` soft-fail.
- [x] **T017** In `Sources/GaiaCore/Dashboard/DashboardState.swift`, documented
  `DashboardSnapshot.demo(...)` as tests/previews only and added
  `DashboardSnapshot.degraded(courseID:now:)` (no placeholder participants) for
  the production failure path.

### Service wiring

- [x] **T018** Added `DashboardService.live(runtime:environment:cache:transport:)`
  in `Sources/GaiaCore/Dashboard/DashboardService.swift` that resolves the Hemera
  base URL from config and injects the auth-backed `HemeraDashboardClient`. The
  Hemera SSE status source (`GAIA_DASHBOARD_SSE_ENDPOINT` via
  `ConnectionStatusMonitor`/`DashboardStatusEvent`) remains the established
  Spec 008 wiring; Aither stays out of card data.
- [x] **T018a** Added `Sources/GaiaCore/Dashboard/AitherPresentationTrigger.swift`
  routing slide/presentation triggers (FR-004) through the Spec 005 auth stack so
  requests carry `Authorization: Bearer` using `GAIA_AITHER_BASE_URL`. Aither is
  kept out of the dashboard card-data path.
- [x] **T019** Structured error mapping in place: `DashboardDataError`
  (transport/non-200) and `LocalEnvironment.ConfigurationError` (missing/invalid
  config); soft-fail per card with no force-unwrap/force-try.

## Phase 3.4: Integration & Hardening

- [x] **T020** Confirmed `Sendable`/actor boundaries hold: `HemeraDashboardClient`
  and `AitherPresentationTrigger` remain `Sendable` structs; `DashboardService` /
  `AuthenticationRuntime` remain actors; no new shared mutable state.
- [x] **T021** Configuration guards added: `serviceBaseURL(_:in:)` and
  `DashboardService.live` fail explicitly when the base URL is missing/invalid
  (FR-009/FR-010; Constitution VI), verified by tests.

## Phase 3.5: Polish & Validation

- [x] **T022** [P] Documented real-data behavior via doc comments on
  `HemeraDashboardClient`, `DashboardSnapshot.degraded`, `DashboardService.live`,
  and `AitherPresentationTrigger`; `quickstart.md` env keys align with
  `LocalEnvironment`.
- [ ] **T023** Validate performance: first usable real-data view ≤2.0s on iPad
  landscape (FR-011) using `scripts/ci-cd/measure-controller-performance.sh`.
  _(Deferred: requires an iPad landscape harness / reachable Hemera instance;
  not runnable in the headless unit-test environment. Run manually against a
  live Hemera instance with `BASE_URL=<hemera-url> COURSE_ID=<id> bash
  scripts/ci-cd/measure-controller-performance.sh` before sign-off.)_
- [x] **T024** Ran `swift build`, full `swift test` (98 tests green), and
  `swift format lint` (clean); Codacy CLI analysis reports **0 issues** on every
  edited source and test file. Re-validated after renaming the stray
  `DashboardURLProtocol 4.swift` → `DashboardURLProtocol.swift` and removing the
  four `URL(string:)!` force-unwraps in `RealDataTestSupport.swift` (replaced
  with a `requireURL(_:)` precondition helper).

---

## Dependencies

- Setup (T001–T002) before everything.
- Tests (T003–T012, incl. T006a) **before** implementation (T013–T019, incl. T018a).
- T013 (config) blocks T014, T018, T018a, T021.
- T014 (transport) blocks T016, T018, T019.
- T006a (Aither trigger test) pairs with T018a (Aither trigger wiring); T018a makes T006a green.
- T016 (remove demo) and T017 (restrict demo) are paired; T016 blocks T008 passing green.
- Implementation (T013–T019, T018a) before integration hardening (T020–T021).
- Everything before polish/validation (T022–T024).

## Parallel Execution Example

```
# After setup, launch the failing test suite together (T003–T012):
Task: "Contract test: auth headers — Tests/contracts/HemeraDashboardAuthHeaderContractTests.swift"
Task: "Contract test: payload mapping — Tests/contracts/HemeraDashboardMappingContractTests.swift"
Task: "Contract test: 401 retry — Tests/contracts/HemeraDashboardRetryContractTests.swift"
Task: "Contract test: soft-fail — Tests/contracts/HemeraDashboardSoftFailContractTests.swift"
Task: "Contract test: Aither trigger Bearer — Tests/contracts/AitherTriggerAuthHeaderContractTests.swift"
Task: "Integration: real data load — Tests/integration/RealDataDashboardLoadTests.swift"
Task: "Integration: no demo on prod path — Tests/integration/NoDemoDataOnProdPathTests.swift"
Task: "Integration: token refresh + retry — Tests/integration/HemeraTokenRefreshRetryTests.swift"
Task: "Integration: stale cache soft-fail — Tests/integration/HemeraStaleCacheSoftFailTests.swift"
Task: "Integration: missing config failure — Tests/integration/MissingConfigExplicitFailureTests.swift"
Task: "Unit: LocalEnvironment service URLs — Tests/GaiaCoreTests/LocalEnvironmentServiceURLTests.swift"
```

## Notes

- [P] tasks = different files, no dependencies.
- Verify each test fails (red) before implementing the corresponding green change.
- Commit after each task.
- Constitution VI: no placeholder runtime data on production paths; missing
  config must fail explicitly.
