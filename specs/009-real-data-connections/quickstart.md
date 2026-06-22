# Quickstart: Validate Real Data Connections

Validation guide proving the dashboard renders real Hemera data (no placeholder
values) and degrades gracefully. See [contracts](./contracts/dashboard-api.md)
and [data-model](./data-model.md) for details.

## Prerequisites

- Swift toolchain (see repo) and VS Code with `swiftlang.swift-vscode`.
- A reachable Hemera instance (or the repo mock for local dev:
  `scripts/ci-cd/mock-controller-bridge-server.py`).
- Service credentials available via environment (never committed).

## Setup

Create `.env.local` at the repository root (gitignored):

```
GAIA_HEMERA_BASE_URL=http://localhost:3500
GAIA_AITHER_BASE_URL=http://localhost:3600
GAIA_HEMERA_API_KEY=<your-hemera-service-key>
GAIA_AITHER_BEARER_TOKEN=<your-aither-service-token>
# Optional overrides (defaults exist):
# GAIA_DASHBOARD_SSE_ENDPOINT=/api/dashboard/status/events
# GAIA_DASHBOARD_CACHE_TTL_SECONDS=45
```

## Build & test

```
swift build
swift test --filter Dashboard
```

(Or use the VS Code tasks `Gaia: Build` and `Gaia: Dashboard Tests`.)

## Validation scenarios

| # | Action                                             | Expected outcome                                                            |
| - | -------------------------------------------------- | --------------------------------------------------------------------------- |
| 1 | Load dashboard with valid credentials              | Real course/participants/status from Hemera; **no** "Alex Example/Sam Sample" placeholders |
| 2 | Search runtime path for demo data                  | `DashboardSnapshot.demo` is **not** reachable on the production fetch path  |
| 3 | Force a Hemera `401`                               | Credential refreshed once and request retried once (Spec 005)               |
| 4 | Make Hemera unavailable with a warm cache          | Last cached snapshot shown, marked stale with "Daten evtl. veraltet", only affected card degrades |
| 5 | Unset `GAIA_HEMERA_BASE_URL`                       | Explicit failure (no demo data served)                                      |

## Performance check

- First usable real-data view renders within ≤2.0s on iPad landscape (FR-011).
  Use `scripts/ci-cd/measure-controller-performance.sh` as a reference harness.

## Success criteria

- Real Hemera data appears in all cards (Connection Monitor, Participant
  Overview, System Status).
- No placeholder/dummy data on the production path.
- Soft-fail, stale-cache warning, and one-retry-on-401 behaviors verified.
