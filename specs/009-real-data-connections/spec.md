# Spec 009: Real Data Connections

## Status

Draft — initial requirements captured.

## Overview

Connect the Gaia dashboard to **real data** from Hemera and Aither. Remove the
dummy/placeholder data currently used to simulate these connections and implement
a **stable API connection** to both services. Reuse the **already defined
authentication procedures** (Spec 005). Real data MUST appear in the dashboard.

## Background

Spec 008 (Dashboard) introduced the dashboard UI and consumed data via mock
servers and placeholder fixtures (see `scripts/ci-cd/mock-aither-slides-server.py`
and `scripts/ci-cd/mock-controller-bridge-server.py`). Spec 009 wires the
dashboard to real service endpoints while preserving the established UX behavior
(soft-fail per card, short-lived cache with revalidation, SSE-driven status).

## Objectives

1. Connect the dashboard to real Hemera endpoints (all card data) instead of
   mocks; use Aither only for slide/presentation triggers.
2. Authenticate service-to-service calls using the credentials defined in Spec 005.
3. Stream live connection/system status via SSE from Hemera (no periodic polling).
4. Fetch and revalidate participant and course data with a short-lived cache.
5. Preserve soft-fail degradation: only affected cards show errors.

## Clarifications

### Session 2026-06-16

- Q: How should the service endpoints (base URLs) for Hemera and Aither be provided/configured? → A: Configurable base URL per service via environment variables / config file (dev/staging/prod separated).
- Q: Which data source (Hemera vs. Aither) feeds which dashboard card? → A: Hemera provides all card data (participants, status, system); Aither is used only for slide/presentation triggers.
- Q: How should the service credentials be provisioned for local dev and CI? → A: Analogous to Aither — sourced from environment variables or a secrets manager (per Spec 005 FR-009); never an interactive user session and never committed to source.
- Q: What performance target applies to the first usable real-data dashboard view on iPad landscape? → A: ≤2.0 seconds (consistent with Spec 008).
- Q: How should Gaia retrieve the dashboard data from Hemera? → A: A single aggregated snapshot endpoint per course (`DashboardSnapshot`), as already modeled in the existing client.

## Requirements

### Functional Requirements

- **FR-001**: The dashboard MUST display **real data** retrieved from Hemera.
  No simulated, dummy, or hard-coded placeholder values may be shown to the user
  in production paths.
- **FR-002**: All **dummy/placeholder data used to simulate the Hemera and
  Aither connections MUST be removed** from the dashboard runtime data path
  (e.g. the placeholder values surfaced via `Sources/GaiaCore/Dashboard/DashboardState.swift`).
- **FR-003**: Gaia MUST implement a **stable API connection** to Hemera as the
  source for **all dashboard card data** — participants, course, connection/
  service status, and system health
  (`Sources/GaiaCore/Dashboard/HemeraDashboardClient.swift`,
  `DashboardService.swift`).
- **FR-004**: Gaia MUST implement a **stable API connection** to Aither used
  **only for slide/presentation triggers** (not as a source for dashboard card
  data). The trigger uses the protected Aither sync contract authenticated with
  `Authorization: Bearer` (Spec 005). The concrete trigger endpoint path/payload
  is documented in `contracts/dashboard-api.md`; this feature wires the
  authenticated transport and verifies the `Bearer` header, while broader
  presentation-trigger behavior remains owned by the controller-bridge path.
- **FR-005**: Both connections MUST reuse the **authentication procedures
  already defined in Spec 005**: dedicated server-side service credentials with
  the target-specific downstream wire format — `X-API-Key` for Hemera service
  APIs and `Authorization: Bearer` for protected Aither operations — including
  per-service token caching and one retry on token expiry
  (`Sources/GaiaCore/Authentication/HemeraServiceAuthenticator.swift`,
  `AitherServiceAuthenticator.swift`, `ServiceTokenCacheStore.swift`).
- **FR-006**: Real data from Hemera MUST populate all data-bearing dashboard
  cards: Connection Monitor, Participant Overview, and System Status.
- **FR-007**: The established UX behavior from Spec 008 MUST be preserved when
  switching to real data:
  - Soft-fail per card (only affected cards show an error).
  - Short-lived cache with revalidation (30–60s).
  - Event-driven status updates via SSE (no periodic polling).
  - Stale-data warning ("Daten evtl. veraltet") when cached data is served.
- **FR-008**: A "stable" connection MUST handle transient failures gracefully
  (timeouts, `401`/token expiry, `5xx`) using the defined retry/cache behavior
  without crashing or showing dummy data.
- **FR-009**: Hemera and Aither base URLs MUST be configurable per service via
  environment variables / a config file, with separate values for dev, staging,
  and prod. URLs MUST NOT be hard-coded in source.
- **FR-010**: Service credentials MUST be provisioned analogously to Aither —
  sourced from environment variables or a secrets manager per Spec 005 FR-009 —
  for both local dev and CI. Credentials MUST NOT be committed to source or
  derived from an interactive user session.
- **FR-011**: The first usable real-data dashboard view MUST render within
  ≤2.0 seconds on iPad landscape (consistent with Spec 008), using cache-first
  display with background revalidation where applicable.
- **FR-012**: Gaia MUST retrieve dashboard data from Hemera via a single
  aggregated `DashboardSnapshot` per course at the **consumer-facing contract
  boundary** (`HemeraDashboardClient.loadSnapshot(courseID:)`). Per-card data is
  derived from that snapshot rather than separate per-card endpoints. Note: the
  internal wire decomposition MAY compose existing Hemera responses behind that
  facade (see `research.md` §3); FR-012 constrains the dashboard-facing contract,
  not the underlying transport layout.

### Acceptance Scenarios

1. **Given** valid service credentials, **When** the dashboard loads, **Then**
   it shows real participant, course, and status data sourced from Hemera (no
   placeholder values); Aither is invoked only for slide/presentation triggers.
2. **Given** the codebase, **When** searching the dashboard runtime path,
   **Then** no simulated/dummy connection data remains in production code paths.
3. **Given** a downstream `401`, **When** a request is made, **Then** the
   service token is refreshed once and the request is retried per Spec 005.
4. **Given** Hemera is unavailable, **When** the dashboard renders, **Then** the
   last valid cached data is shown with the "Daten evtl. veraltet" warning and
   only the affected card degrades.

## Non-Goals

- UI/layout redesign beyond what is required to surface real data.
- Changing the authentication contract defined in Spec 005.

## Open Questions

_All critical clarifications captured in this session have been resolved. Remaining
endpoint-shape details (exact field schema of `DashboardSnapshot` from Hemera) are
deferred to the planning phase (`/speckit.plan`)._
