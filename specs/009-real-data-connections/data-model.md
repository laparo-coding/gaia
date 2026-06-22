# Phase 1 Data Model: Real Data Connections

This feature reuses the existing dashboard entities defined in
`Sources/GaiaCore/Dashboard/DashboardState.swift`. No new persisted entities are
introduced; the entities below form the contract surface between Hemera and the
dashboard view models.

## Entities

### DashboardSnapshot

The aggregate view the dashboard consumes per course (FR-012).

| Field          | Type                      | Notes                                   |
| -------------- | ------------------------- | --------------------------------------- |
| course         | DashboardCourse           | Required                                |
| participants   | [DashboardParticipant]    | May be empty                            |
| connection     | DashboardConnectionStatus | Aither + Hemera connection states       |
| system         | DashboardSystemMetrics    | Version, service health, last update    |
| isStale        | Bool                      | True when served from cache on failure  |
| warningMessage | String?                   | "Daten evtl. veraltet" when stale       |

State transitions (via `DashboardCache` freshness):
`fresh` → return as-is; `stale` → return `markingStale()`; `expired`/`missing`
→ fetch; on fetch failure with usable cache → `markingStale()`; with no cache →
structured per-card error (soft-fail). **No `demo(...)` on production path.**

### DashboardCourse

| Field | Type   | Notes    |
| ----- | ------ | -------- |
| id    | String | Required |
| title | String | Required |

### DashboardParticipant

| Field       | Type   | Notes                        |
| ----------- | ------ | ---------------------------- |
| id          | String | Required, `Identifiable`     |
| displayName | String | Required                     |
| avatarURL   | URL?   | Optional; parsed from string |

### DashboardConnectionStatus

| Field  | Type                    | Notes |
| ------ | ----------------------- | ----- |
| aither | DashboardConnectionState | connected / disconnected / connecting |
| hemera | DashboardConnectionState | connected / disconnected / connecting |

### DashboardSystemMetrics

| Field         | Type                  | Notes                              |
| ------------- | --------------------- | ---------------------------------- |
| version       | String                | Software version                   |
| serviceStatus | DashboardServiceHealth | healthy / degraded / unavailable   |
| lastUpdatedAt | Date                  | ISO8601 from Hemera                 |

## Hemera response → entity mapping

| Hemera response field                 | Maps to                                   |
| ------------------------------------- | ----------------------------------------- |
| `course.id`, `course.title`           | `DashboardCourse`                         |
| `participants[].id/displayName/avatarUrl` | `DashboardParticipant`                |
| `connection.aither`, `connection.hemera`  | `DashboardConnectionStatus`           |
| `system.serviceStatus`, `system.lastUpdatedAt`, `version` | `DashboardSystemMetrics` |
| `cache.isStale`, `cache.ttlSeconds`   | `isStale` / cache TTL behavior            |
| `events.transport`, `events.endpoint` | SSE status source wiring                  |

## Validation rules

- Missing required configuration (base URL, credential) → explicit failure, not
  demo data (Constitution VI; FR-002, FR-009, FR-010).
- `401`/expiry from Hemera → refresh credential once and retry once (Spec 005
  FR-012; reflected in FR-005/FR-008).
- Non-200 responses → soft-fail to stale cache or structured per-card error.
