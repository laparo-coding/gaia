# Research: Dashboard

## Context

Spec 008 introduces non-trivial architecture decisions around status transport, cache revalidation, partial failure behavior, role-gated actions, and performance constraints on iPad landscape. This document records selected approaches and rejected alternatives before implementation.

## Decision 1: Status Transport for Connection/System Updates

- Decision: Use Server-Sent Events (SSE) for event-driven connection and system status updates.
- Why:
  - Satisfies no-periodic-polling requirement.
  - Keeps client/server complexity lower than full bidirectional WebSocket for this scope.
  - Supports incremental reconnect/backoff without additional protocol complexity.
- Rejected alternatives:
  - WebSocket: More flexibility but unnecessary bidirectional overhead for current one-way status feed.
  - Long polling: Rejected because it violates no-periodic-polling direction.

## Decision 2: Data Freshness and Fallback

- Decision: Cache Hemera course/participant data with short TTL (30-60 seconds) and revalidate after TTL expiration.
- Why:
  - Balances responsiveness and backend load.
  - Enables fallback to last valid snapshot during transient outages.
  - Supports explicit stale warning requirement.
- Rejected alternatives:
  - No cache: Increases latency and outage fragility.
  - Long-lived cache (>60s): Higher stale-data risk for participant updates.

## Decision 3: Failure Isolation

- Decision: Apply soft-fail per card; only impacted card shows an error.
- Why:
  - Preserves dashboard usability when one service path degrades.
  - Aligns with requirement for partial-service resilience.
- Rejected alternatives:
  - Global hard-fail view: Overly disruptive and obscures healthy signals.

## Decision 4: Authorization for Seminar Action

- Decision: Allow `Seminar starten` only for role `moderator`.
- Why:
  - Converts ambiguous role wording into deterministic policy.
  - Limits critical action scope while retaining dashboard visibility for other roles.
- Rejected alternatives:
  - Any authenticated role: Weakens control.
  - Placeholder-only action: Delays functional acceptance path.

## Decision 5: System Metrics Scope (v1)

- Decision: Limit system status card to software version, service status, and last update timestamp.
- Why:
  - Meets immediate observability needs with minimal implementation risk.
  - Protects performance target while keeping UI concise.
- Rejected alternatives:
  - Expanded runtime metrics (CPU/memory/network): Deferred to follow-up feature scope.

## Decision 6: Validation Scope

- Decision: Validate responsiveness on iPad landscape breakpoints (11-inch and 13-inch) and enforce first usable view <=2.0 seconds.
- Why:
  - Aligns directly with constitution orientation scope and spec success criteria.
  - Produces measurable acceptance gates.

## Finalized Ownership and Payload Notes

- SSE endpoint ownership: `GaiaAuthenticationApp` owns `/api/dashboard/status/events` and is the source of emitted dashboard status events.
- Client responsibility: `ConnectionStatusMonitor` consumes SSE lines, decodes typed events, and maps them into card-level dashboard updates.
- Payload responsibility split:
  - `/api/dashboard/status`: bootstrap snapshot (connection + system + events metadata).
  - `/api/dashboard/status/events`: incremental status changes (`connection.changed`, `system.changed`, `stream.error`).
  - `/api/dashboard/participants`: participant/course payload plus cache freshness metadata.
  - `/api/dashboard/system-health`: minimal metrics payload (version, serviceStatus, lastUpdatedAt).