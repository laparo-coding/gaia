# Implementation Plan: Real Data Connections

**Branch**: `009-real-data-connections` | **Date**: 2026-06-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-real-data-connections/spec.md`

## Summary

Connect the Gaia dashboard to real data from Hemera and remove the dummy/demo
fallback data currently used to simulate the connection. Today
`HemeraDashboardClient` fetches over a bare `URLSession` and, on any failure,
falls back to `DashboardSnapshot.demo(...)` (the "Alex Example / Mara Muster /
Sam Sample" placeholders). This feature routes Hemera traffic through the
existing Spec 005 authentication stack (`AuthenticationRuntime` +
`DownstreamServiceClient`, `X-API-Key`), makes the base URL configurable per
environment, preserves the established Spec 008 UX (soft-fail per card,
short-lived cache + revalidation, SSE status, "Daten evtl. veraltet" warning),
and uses Aither only for slide/presentation triggers (`Authorization: Bearer`).

## Technical Context

**Language/Version**: Swift 6.x (package targets), Swift 6.1 manifest
**Primary Dependencies**: SwiftPM only, Foundation (`URLSession`), existing
`GaiaCore` modules (`Authentication`, `Dashboard`, `Configuration`)
**Storage**: In-memory `DashboardCache` (short-lived snapshot cache, TTL 30-60s);
no persistent storage
**Testing**: Swift Testing / XCTest per existing `GaiaCoreTests` convention;
contract tests under `Tests/contracts`, integration under `Tests/integration`
**Target Platform**: iPad landscape (primary), Linux CLI build for CI/tests
**Project Type**: swift-package
**Editor Workflow**: VS Code + `swiftlang.swift-vscode` + LLDB DAP; tasks
`Gaia: Build`, `Gaia: Dashboard Tests`, `swift-format` lint
**Performance Goals**: First usable real-data dashboard view <=2.0s on iPad
landscape (FR-011); cache-first display with background revalidation
**Constraints**: Sendable-safe (`HemeraDashboardClient` is a `Sendable` struct,
`DashboardService`/`AuthenticationRuntime` are actors); no secrets in source;
no placeholder runtime data on production paths (Constitution VI)
**Scale/Scope**: Single feature within `GaiaCore`; touches Dashboard data path
and its wiring to the Authentication runtime + Configuration

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- [x] Specs-first flow preserved: `spec.md` -> `plan.md` -> `tasks.md` before implementation
- [x] Tests are designed to fail before implementation begins (contract + integration tests authored first, Constitution II)
- [x] Structure uses `Package.swift`, `Sources/`, and `Tests/` (no exception needed)
- [x] VS Code build, test, debug, format, and lint commands are identified (see Editor Workflow)
- [x] Swift API design, concurrency, and type-safety implications documented (Sendable struct client, actor runtime, structured errors)
- [x] Security, observability, and failure handling covered (Spec 005 auth, no demo fallback on prod path, soft-fail, structured errors)

**Result**: PASS. No violations; Complexity Tracking not required.

### Key constitutional alignment notes

- **VI. Security**: `DashboardSnapshot.demo(...)` is placeholder runtime behavior
  on a production-critical path and MUST be removed from the live fetch path
  (Constitution: "placeholder runtime behavior is forbidden for
  production-critical code paths"). Missing required configuration (base URL,
  credentials) MUST fail explicitly rather than silently serving demo data.
- **IV. Concurrency**: Reuse existing `Sendable`/actor boundaries; no new shared
  mutable state.
- **Device scope**: All UX/perf acceptance validated against iPad landscape.

## Project Structure

### Documentation (this feature)

\`\`\`
specs/009-real-data-connections/
|-- plan.md              # This file (/speckit.plan output)
|-- research.md          # Phase 0 output
|-- data-model.md        # Phase 1 output
|-- quickstart.md        # Phase 1 output
|-- contracts/           # Phase 1 output (Hemera dashboard API contract)
\`-- tasks.md             # Phase 2 output (/speckit.tasks - NOT created here)
\`\`\`

### Source Code (repository root)

\`\`\`
Package.swift
Sources/
\`-- GaiaCore/
    |-- Authentication/          # Reused: AuthenticationRuntime, DownstreamServiceClient,
    |                            #         HemeraServiceAuthenticator, ServiceTokenCacheStore
    |-- Configuration/
    |   \`-- LocalEnvironment.swift   # Extend: per-service base URL keys (Hemera/Aither)
    \`-- Dashboard/
        |-- HemeraDashboardClient.swift   # Modify: auth-backed transport; remove demo fallback
        |-- DashboardService.swift        # Wire: inject configured client
        |-- DashboardState.swift          # Modify: keep demo only for tests/previews, not prod
        |-- DashboardCache.swift          # Reused: TTL cache + freshness
        \`-- ConnectionStatusMonitor.swift # Reused/SSE status

Tests/
|-- GaiaCoreTests/        # Unit tests (client mapping, config, fallback behavior)
|-- contracts/            # Contract tests for Hemera dashboard endpoints
\`-- integration/          # End-to-end auth + dashboard load scenarios
\`\`\`

**Structure Decision**: Standard SwiftPM layout (Constitution V). All work lands
in the existing `GaiaCore` target under `Authentication`, `Configuration`, and
`Dashboard`; tests split across `GaiaCoreTests`, `contracts`, and `integration`
mirroring the established repository convention. No new targets or apps required.

## Phase 0: Outline & Research

Unknowns and decisions to resolve in `research.md`:

1. **Auth integration shape** - How to route `HemeraDashboardClient` traffic
   through `AuthenticationRuntime`/`DownstreamServiceClient` (inject the client
   vs. inject a `Transport` closure that adds `X-API-Key`). Decision + rationale.
2. **Demo fallback removal** - Define the explicit failure behavior that replaces
   `DashboardSnapshot.demo(...)`: serve stale cache when available, otherwise a
   structured per-card error (soft-fail), never placeholder data on prod path.
3. **Endpoint contract** - Spec clarified "single aggregated snapshot per course"
   (FR-012), but current code uses 3 endpoints (`participants`, `status`,
   `system-health`). Decision: keep the 3-endpoint composition behind the
   `loadSnapshot` facade (the public contract is the snapshot) OR migrate to one
   aggregate endpoint. Record rationale and impact.
4. **Configuration** - Per-service base URL keys in `LocalEnvironment`
   (`GAIA_HEMERA_BASE_URL`, `GAIA_AITHER_BASE_URL`) with dev/staging/prod values;
   explicit failure when missing (Constitution VI).
5. **SSE status source** - Confirm Hemera-provided SSE endpoint
   (`GAIA_DASHBOARD_SSE_ENDPOINT` already exists) is the status source; Aither
   not used for card data.
6. **Best practices** - Swift 6 `Sendable`/actor patterns for the auth-backed
   client; URLSession + Bearer/X-API-Key injection; one-retry-on-401 reuse.

**Output**: `research.md` with all decisions resolved (no NEEDS CLARIFICATION).

## Phase 1: Design & Contracts

_Prerequisites: research.md complete_

1. **`data-model.md`** - Document existing dashboard entities used as the
   contract surface: `DashboardSnapshot`, `DashboardCourse`,
   `DashboardParticipant`, `DashboardConnectionStatus`,
   `DashboardSystemMetrics`, plus cache freshness states. Note the field schema
   each Hemera response maps to.
2. **`contracts/`** - Capture the Hemera dashboard API contract consumed by
   `HemeraDashboardClient`: request (auth headers `X-API-Key`, `courseId`),
   response schemas for participants/status/system-health (or the aggregate
   snapshot), and error/`401` semantics. Document Aither slide/presentation
   trigger contract (`Authorization: Bearer`).
3. **Contract tests** - One failing test per endpoint asserting request headers
   (auth) and response->view-model mapping. Tests MUST fail before implementation.
4. **Integration scenarios** - From the spec's acceptance scenarios: (a) real
   data load with valid credentials, (b) no dummy data remains on prod path,
   (c) `401` -> refresh once + retry, (d) Hemera unavailable -> stale cache +
   warning + per-card soft-fail. Map to `Tests/integration`.
5. **`quickstart.md`** - Runnable validation: set env (`.env.local`) with base
   URLs + credentials, `swift build`, run dashboard tests, expected outcome:
   real snapshot rendered, no placeholder names, stale-warning path verified.
6. **Agent context update** - Run `.specify/scripts/bash/update-agent-context.sh copilot`
   to record new tech/paths; preserve manual additions; update the plan
   reference between the SPECKIT markers in `.github/copilot-instructions.md`.

**Output**: `data-model.md`, `contracts/*`, failing contract/integration tests,
`quickstart.md`, updated agent context.

## Phase 2: Task Planning Approach

_Described here; executed by `/speckit.tasks` (DO NOT create tasks.md now)._

**Task Generation Strategy**:

- Load `.specify/templates/tasks-template.md` as base.
- Each contract (Hemera endpoints, Aither trigger) -> contract test task [P].
- Each entity in `data-model.md` -> model/mapping verification task [P].
- Each acceptance scenario -> integration test task.
- Implementation tasks to make tests pass:
  - Extend `LocalEnvironment` with per-service base URL keys + explicit failure.
  - Inject auth-backed transport into `HemeraDashboardClient`
    (`DownstreamServiceClient`/`AuthenticationRuntime`, `X-API-Key`).
  - Remove `DashboardSnapshot.demo(...)` from the live fetch path; replace with
    stale-cache-or-structured-error soft-fail; keep demo only for tests/previews.
  - Wire `DashboardService` composition + SSE status source.

**Ordering Strategy**:

- TDD order: contract + integration tests first (red), then implementation (green).
- Dependency order: configuration -> auth-backed client -> service wiring -> SSE.
- Mark [P] for independent files (separate endpoints/entities).

**Estimated Output**: 15-25 numbered, ordered tasks in tasks.md.

## Complexity Tracking

No constitutional violations identified. No deviations to justify.

## Progress Tracking

**Phase Status**:

- [x] Phase 0: Research complete (`research.md`)
- [x] Phase 1: Design complete (`data-model.md`, `contracts/`, `quickstart.md`)
- [x] Phase 2: Task planning approach described (/plan)
- [ ] Phase 3: Tasks generated (/speckit.tasks)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none)
- [x] Agent context updated

**STOP** - Ready for `/speckit.tasks`.

---

_Based on the active repository constitution - See `/.specify/memory/constitution.md`_
