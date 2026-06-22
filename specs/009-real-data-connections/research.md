# Phase 0 Research: Real Data Connections

All decisions below resolve the unknowns from `plan.md`. No NEEDS CLARIFICATION
markers remain.

## 1. Auth integration shape

- **Decision**: Inject a `Sendable` transport into `HemeraDashboardClient` that
  is backed by the existing `DownstreamServiceClient` + `AuthenticationRuntime`
  (Spec 005). The client keeps its current `Transport`-style seam; production
  wiring supplies an auth-aware transport that attaches `X-API-Key` for Hemera,
  while tests supply an in-memory transport.
- **Rationale**: Minimal change to the existing `Sendable` struct; preserves
  testability (no global state); reuses Spec 005 token caching and the
  one-retry-on-`401` behavior already implemented in
  `AuthenticationRuntime.executeAuthorizedServiceRequest`.
- **Alternatives considered**:
  - Have `HemeraDashboardClient` call `URLSession` directly and add headers
    manually — rejected: duplicates token caching/refresh and violates DRY +
    Constitution V (shared code must be reused).
  - Make the client an actor — rejected: unnecessary; struct + injected
    `Sendable` transport already satisfies concurrency safety.

## 2. Demo fallback removal

- **Decision**: Remove `DashboardSnapshot.demo(...)` from the live fetch path in
  `loadSnapshot`. New failure behavior: (1) if usable cache exists, return it
  marked stale with "Daten evtl. veraltet"; (2) otherwise surface a structured
  per-card error so only the affected card degrades (soft-fail). `demo(...)`
  remains available only for tests and SwiftUI previews, not production.
- **Rationale**: Constitution VI forbids placeholder runtime behavior on
  production-critical paths and requires explicit failure for missing config.
  Spec FR-001/FR-002 require no dummy data on production paths.
- **Alternatives considered**:
  - Keep demo as a last-resort fallback — rejected: directly violates FR-002 and
    Constitution VI.
  - Crash on failure — rejected: violates soft-fail UX (FR-007) and graceful
    degradation (Constitution VI).

## 3. Endpoint contract (aggregate vs. composed)

- **Decision**: Keep the public contract as a single `DashboardSnapshot` per
  course via `loadSnapshot(courseID:)`. Internally retain the existing
  composition of `participants`, `status`, and `system-health` fetches behind
  that facade for now; FR-012 is satisfied at the contract boundary (one
  snapshot per course to the dashboard).
- **Rationale**: FR-012 constrains the consumer-facing contract, not the wire
  decomposition. The composition already exists, runs concurrently
  (`async let`), and minimizes risk. A future aggregate endpoint can be adopted
  without changing the dashboard contract.
- **Alternatives considered**:
  - Immediately migrate Hemera to one aggregate endpoint — deferred: requires
    Hemera-side changes outside this feature's scope; tracked as future work.

## 4. Configuration

- **Decision**: Extend `LocalEnvironment` with per-service base URL keys
  `GAIA_HEMERA_BASE_URL` and `GAIA_AITHER_BASE_URL`, loaded from `.env.local`
  (local) and process environment (CI). Missing required base URL or credential
  MUST fail explicitly (thrown/structured error), never silently serve demo data.
- **Rationale**: Mirrors the existing `LocalEnvironment` pattern (e.g.
  `GAIA_DASHBOARD_SSE_ENDPOINT`, `GAIA_DASHBOARD_CACHE_TTL_SECONDS`); satisfies
  FR-009 (configurable, per-environment, not hard-coded) and Constitution VI
  (explicit failure on missing config; no secrets in source).
- **Alternatives considered**:
  - Hard-coded prod URLs — rejected by FR-009.
  - Single combined base URL — rejected: Hemera and Aither are distinct services.

## 5. SSE status source

- **Decision**: Connection/system status updates stream from the Hemera-provided
  SSE endpoint resolved via the existing `GAIA_DASHBOARD_SSE_ENDPOINT`
  configuration. Aither is invoked only for slide/presentation triggers and is
  not a source of dashboard card data.
- **Rationale**: Matches clarification (Hemera = all card data) and FR-007
  (event-driven via SSE, no polling). The SSE plumbing already exists from
  Spec 008 (`DashboardStatusEvent`, `ConnectionStatusMonitor`,
  `HTTPChunkedTransfer`).
- **Alternatives considered**:
  - Periodic polling — rejected by FR-007.
  - Aither-sourced status — rejected by clarification (Aither = triggers only).

## 6. Swift 6 best practices

- **Decision**: Keep `HemeraDashboardClient` a `Sendable` struct with an injected
  `@Sendable` transport; rely on the `DashboardService` actor for cache
  coordination and `AuthenticationRuntime` actor for token state. Use structured
  error types over stringly-typed failures; no force-unwrap/force-try.
- **Rationale**: Constitution IV (concurrency discipline, Sendable boundaries,
  structured errors) and existing repository patterns.
- **Sources**: Swift.org concurrency documentation; existing Spec 005
  implementation (`DownstreamServiceClient`, `AuthenticationRuntime`).
  (Perplexity MCP not used; relied on primary sources per Constitution I.)
