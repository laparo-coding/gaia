# Dashboard API Contracts

## Overview

These contracts define the API surfaces required by Dashboard feature 008.

## GET /api/dashboard/status

Purpose: Provide current connection/system status bootstrap and stream metadata.

Response 200

```json
{
  "connection": {
    "aither": "connected",
    "hemera": "connecting"
  },
  "system": {
    "serviceStatus": "degraded",
    "lastUpdatedAt": "2026-06-06T18:00:00Z"
  },
  "events": {
    "transport": "sse",
    "endpoint": "/api/dashboard/status/events"
  }
}
```

Connection state enum:

- connected
- disconnected
- connecting

System service status enum:

- healthy
- degraded
- unavailable

Errors:

- 503 ServiceUnavailable: status provider unavailable
- 500 InternalError: unexpected server-side failure

## GET /api/dashboard/status/events

Purpose: SSE stream for event-driven status updates (no periodic polling).

Transport:

- Content-Type: text/event-stream
- Cache-Control: no-cache

Event payload shape:

```json
{
  "type": "connection.changed",
  "timestamp": "2026-06-06T18:00:05Z",
  "connection": {
    "aither": "connected",
    "hemera": "connected"
  },
  "system": {
    "serviceStatus": "healthy",
    "lastUpdatedAt": "2026-06-06T18:00:05Z"
  }
}
```

Supported event types:

- connection.changed
- system.changed
- stream.error

Errors:

- 503 ServiceUnavailable: stream source unavailable

## GET /api/dashboard/participants

Purpose: Return participant and course snapshot for dashboard cards.

Query parameters:

- courseId (required)

Response 200

```json
{
  "course": {
    "id": "course-123",
    "title": "Gaia Seminar"
  },
  "participants": [
    {
      "id": "user-1",
      "displayName": "Alex Example",
      "avatarUrl": "https://example.com/avatar/alex.png"
    }
  ],
  "cache": {
    "isStale": false,
    "ttlSeconds": 45
  }
}
```

Fallback behavior:

- If Hemera is unavailable and a valid cached snapshot exists, return 200 with `cache.isStale=true`.
- Client must show warning notice: `Daten evtl. veraltet` when `cache.isStale=true`.

Errors:

- 400 BadRequest: missing/invalid courseId
- 503 ServiceUnavailable: no cached snapshot and upstream unavailable
- 500 InternalError: unexpected server-side failure

## GET /api/dashboard/system-health

Purpose: Provide minimal metrics for system status card.

Response 200

```json
{
  "version": "1.0.0",
  "serviceStatus": "healthy",
  "lastUpdatedAt": "2026-06-06T18:00:00Z"
}
```

Errors:

- 503 ServiceUnavailable: health provider unavailable
- 500 InternalError: unexpected server-side failure

## Authorization Notes

- Dashboard read endpoints are available to authenticated dashboard sessions.
- Seminar start action is role-gated to `moderator` in application logic and is not exposed by these read contracts.