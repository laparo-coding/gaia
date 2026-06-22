# Phase 1 Contracts: Hemera Dashboard API + Aither Triggers

Defines the contracts consumed by `HemeraDashboardClient` and the Aither
slide/presentation trigger. All Hemera requests are authenticated with
`X-API-Key`; Aither protected operations use `Authorization: Bearer` (Spec 005).

## Authentication (all requests)

| Service | Header                         | Source                                  |
| ------- | ------------------------------ | --------------------------------------- |
| Hemera  | `X-API-Key: <service-key>`     | Env/secrets (FR-010), Spec 005 FR-008a  |
| Aither  | `Authorization: Bearer <token>`| Env/secrets (FR-010), Spec 005 FR-008b  |

On `401`/`WWW-Authenticate`: refresh the credential once and retry once
(Spec 005 FR-012).

## Hemera: GET /api/dashboard/participants?courseId={id}

**Response 200**

```json
{
  "course": { "id": "course-123", "title": "Gaia Seminar" },
  "participants": [
    { "id": "user-1", "displayName": "Alex Beispiel", "avatarUrl": "https://…" }
  ],
  "cache": { "isStale": false, "ttlSeconds": 45 }
}
```

## Hemera: GET /api/dashboard/status

**Response 200**

```json
{
  "connection": { "aither": "connected", "hemera": "connected" },
  "system": { "serviceStatus": "healthy", "lastUpdatedAt": "2026-06-16T20:48:00Z" },
  "events": { "transport": "sse", "endpoint": "/api/dashboard/status/events" }
}
```

`connection.*` ∈ `connected | disconnected | connecting`.
`system.serviceStatus` ∈ `healthy | degraded | unavailable`.

## Hemera: GET /api/dashboard/system-health

**Response 200**

```json
{ "version": "1.0.0", "serviceStatus": "healthy", "lastUpdatedAt": "2026-06-16T20:48:00Z" }
```

## Hemera: SSE /api/dashboard/status/events

Event-driven connection/system status (FR-007). Configured via
`GAIA_DASHBOARD_SSE_ENDPOINT`. Each event carries an updated status payload
consumed by `ConnectionStatusMonitor`/`DashboardStatusEvent`.

## Aither: slide/presentation trigger (Bearer)

Used only for slide/presentation triggers (not dashboard card data). Authenticated
with `Authorization: Bearer <token>` via the Spec 005 auth transport
(`AitherServiceAuthenticator`), with base URL from `GAIA_AITHER_BASE_URL`.

**Request** (representative; concrete path owned by Aither's protected sync
contract):

```
POST {GAIA_AITHER_BASE_URL}/api/presentation/trigger
Authorization: Bearer <service-token>
Content-Type: application/json

{ "courseId": "course-123", "action": "advance" }
```

**Contract scope for this feature**: verify the request is routed through the
authenticated transport and carries `Authorization: Bearer`. Trigger semantics
(slide advance/jump payloads) remain owned by the controller-bridge path and are
not redefined here.

## Error semantics

| Condition         | Behavior                                                   |
| ----------------- | ---------------------------------------------------------- |
| `401` / expiry    | Refresh credential once, retry once (Spec 005)             |
| Non-200 / network | Soft-fail: serve usable stale cache (marked) or per-card error |
| Missing config    | Explicit failure; never serve demo/placeholder data        |

## Contract test expectations (must fail before implementation)

1. Hemera requests include `X-API-Key`; Aither trigger includes `Bearer`.
2. 200 payloads map correctly to `DashboardSnapshot` fields.
3. `401` triggers exactly one refresh + one retry.
4. Failure with usable cache returns a stale snapshot with the warning; failure
   without cache yields a structured per-card error (no demo data).
