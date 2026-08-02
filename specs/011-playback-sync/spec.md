# Spec 011: Playback Sync

## Status

Draft — ready for `/clarify`, `/plan`, `/tasks`.

## Clarifications

### Session 2026-08-02

- Q: Was passiert, wenn der Operator bereits manuell auf eine Position nach dem ersten Kapitel gesucht hat und dann ein `play`-SSE-Kommando eintrifft? Soll Gaia trotzdem auf Kapitel 0 zurückspringen, oder ab der aktuellen Position abspielen? → A: **Immer auf Kapitel 0 springen (Option A).** Beim ersten `play`-Kommando (egal ob via SSE oder manuellem Button) sucht Gaia deterministisch auf `chapters[0].start`, unabhängig von der aktuellen Position. Das `hasPlayedOnce`-Flag verhindert wiederholtes Springen bei nachfolgenden `play`-Kommandos. Begründung: Sync-Konsistenz mit dem Aither-Web-Player (Aither Spec 011, FR-002 sucht ebenfalls immer auf `chapters[0].start` beim ersten Play). Wenn Gaia anders reagiert, sind beide Player nicht mehr synchron — das widerspricht dem Kernziel dieser Spec.
- Q: Wie soll der `PlaybackCommandMonitor` mit einem abgelaufenen/ungültigen Bearer-Token umgehen (401 auf den SSE-Request)? → A: **Token erneuern + retry (Option B).** Der Monitor nutzt die bestehende `ServiceAuthorizationCoordinator`-Retry-Logik: bei HTTP 401 auf den initialen SSE-Verbindungsaufbau wird der Token-Cache invalidiert, der `AitherServiceAuthenticator` fordert einen neuen Token an (Provider liest `AITHER_SYNC_TOKEN` neu), und der SSE-Request wird einmalig wiederholt. Schlägt der Retry ebenfalls fehl (Token wirklich ungültig), stoppt der Monitor die Reconnect-Versuche. Begründung: Bestehende Infrastruktur (`ServiceAuthorizationCoordinator` hat bereits 401-Retry mit Cache-Invalidierung), kein Operator-Eingriff nötig, Sync bleibt nach kurzer Unterbrechung wiederhergestellt. Einschränkung: Die Retry-Logik greift nur beim initialen Verbindungsaufbau, nicht für Mid-Stream-Expiry — das ist akzeptabel, da SSE-Verbindungen beim nächsten Reconnect (nach Netzwerkfehler) den frischen Token nutzen.
- Q: Was passiert, wenn nach 10 fehlgeschlagenen Reconnect-Versuchen Aither immer noch nicht erreichbar ist? → A: **Stoppen + UI-Hinweis (Option C).** Der Monitor stoppt die Reconnect-Versuche nach Erreichen des Caps (NFR-003) und der `VideoPlayerViewModel` zeigt einen Hinweis im Player an („Aither nicht erreichbar — Sync offline“). Der Player bleibt manuell bedienbar (Play-Button funktioniert). Der Operator muss die View neu laden, um die SSE-Sync erneut zu starten. Begründung: Operator-Feedback (im Gegensatz zu stillem Stop), keine endlosen Retries die Batterie/Netzwerk belasten, konsistent mit `ConnectionStatusMonitor` der ebenfalls begrenzte Retries hat.
- Q: Wie soll der Monitor den Delegate-Callback thread-safe ausführen, wenn SSE-Events auf einem Background-Task ankommen? → A: **`Task { @MainActor in }` pro Event (Option A).** Jedes SSE-Event wrappt den Delegate-Aufruf in `Task { @MainActor in delegate.onPlay() }`. Der Monitor läuft auf einem Background-Task (SSE-Streaming via `URLSession.bytes`); nur der Delegate-Aufruf hoppt auf Main-Actor. Begründung: Swift 6 safe (kanonischer Actor-Hop), NFR-001 erfüllt (Background-Task wird nicht blockiert), bestehendes `@MainActor protocol`-Pattern beibehalten (dasselbe Muster wie `ConnectionStatusMonitor`), Performance irrelevant (SSE-Events sind selten, < 1/s).

## Overview

Gaia subscribes to Aither's **SSE playback command channel**
(`/api/recording/events?recordingId=<id>`) so that a single
`POST /api/recording/playback/play` call from any client (dashboard,
programmatic trigger, or the Aither web player itself) starts playback on
**both** the Aither web player and the Gaia controller simultaneously.

Today Gaia's `VideoPlayerViewModel` only plays when the operator presses the
in-app Play button. Aither's `dispatchCommand` already broadcasts `play` /
`stop` / `seek` commands to all SSE clients registered for a recording — but
Gaia is not registered. This spec adds a new `PlaybackCommandMonitor` (analog
to the existing `ConnectionStatusMonitor` for dashboard status SSE) that
listens for playback commands and forwards them to `VideoPlayerViewModel`.

## Background

This feature builds on the existing playback and service-connection work:

- **Spec 005 (Authentication)** defines the `Bearer` service credentials used
  for all Aither API calls. The SSE endpoint requires `requireAdmin` auth —
  Gaia sends the Bearer token via the `Authorization` header.
- **Spec 008 (Dashboard)** and **Spec 009 (Real Data Connections)** establish
  the Gaia ↔ Aither integration and the `DownstreamServiceClient`.
- **Spec 010 (Timestamp Playback)** adds chapter-aware playback, the
  `ChapterSeekLogic`, and the initial-seek-to-`chapters[0].start` behavior.
  This spec reuses the chapter list already loaded by `VideoPlayerViewModel`
  to perform the same initial seek when a `play` command arrives via SSE.
- **Aither Spec 004 (Recording Module)** owns the SSE endpoint
  `/api/recording/events` and the `dispatchCommand` broadcast.
- **Aither Spec 011 (Timestamps in Video)** adds the `startAtFirst` parameter
  and the Aither web player's client-side initial seek. Gaia does not use
  `startAtFirst` — it performs its initial seek client-side (same as the Aither
  web player).

### Existing Infrastructure to Reuse

| Component | File | Reuse |
|-----------|------|------|
| SSE client (URLSession.bytes, `data:` parsing, reconnect backoff) | `Sources/GaiaCore/Dashboard/ConnectionStatusMonitor.swift` | Pattern for new `PlaybackCommandMonitor` |
| HTTP/1.1 chunked transfer helper | `Sources/GaiaCore/Dashboard/HTTPChunkedTransfer.swift` | SSE stream pumping |
| Bearer auth for Aither API | `Sources/GaiaCore/Authentication/AitherServiceAuthenticator.swift` (Spec 005) | `Authorization` header on SSE request |
| Chapter list + initial seek | `app/controller/VideoPlayerViewModel.swift` (Spec 010) | `chapters[0].start` seek on first `play` command |
| Downstream service client | `Sources/GaiaCore/.../DownstreamServiceClient.swift` | Base URL resolution for Aither |

## Out of Scope

- Modifying Aither's SSE endpoint or `dispatchCommand` broadcast — Aither
  already broadcasts to all registered clients; no Aither change needed.
- Changing Gaia's manual Play button — it remains functional; SSE commands
  are an additional trigger, not a replacement.
- Syncing playback position between Gaia and the Aither web player — both
  players play independently; this spec only synchronizes the **start/stop/seek
  commands**, not the live position.
- Adding new SSE event types — only existing `play`, `stop`, `seek`, and
  `chapter-boundary` events are consumed.
- Mobile/native player clients other than Gaia.

## Architecture Overview

```
POST /api/recording/playback/play (any client)
        │
        ▼
Aither dispatchCommand(recordingId, { action: "play" })
        │
        ├──→ SSE → Aither Web-Player → video.play()
        │
        └──→ SSE → Gaia PlaybackCommandMonitor (NEW)
                        │
                        ▼
                  VideoPlayerViewModel.play()
                  (with initial seek to chapters[0].start)
```

1. **Subscribe** — When `VideoPlayerViewModel.preparePlayer()` succeeds (Spec
   010), the view model starts a `PlaybackCommandMonitor` for the same
   `assetId`. The monitor opens an SSE connection to
   `GET /api/recording/events?recordingId=<assetId>` with a Bearer
   `Authorization` header (Spec 005).
2. **Receive commands** — The monitor parses `event: command` messages and
   forwards `play`, `stop`, and `seek` actions to the view model via a
   delegate callback.
3. **Initial seek** — On the first `play` command, the view model seeks to
   `chapters[0].start` (if chapters are loaded) before calling `player.play()`,
   matching the Aither web player's behavior (Aither Spec 011, FR-002) and
   Gaia Spec 010's existing initial-seek logic.
4. **Stop** — A `stop` command calls `player.pause()`.
5. **Seek** — A `seek` command sets `player.seek(to:)` at the given position.
6. **Reconnect** — On SSE error/disconnect, the monitor retries with backoff
   (same pattern as `ConnectionStatusMonitor`: `[0.5, 1, 2, 5]` seconds).
7. **Unsubscribe** — When the view model is deinitialized or the player is
   torn down, the monitor's SSE task is cancelled.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Gaia Plays in Sync with Aither Web Player (Priority: P1)

As a seminar operator, I want Gaia to start playing a recording at the same
time as the Aither web player when I trigger playback from the dashboard, so
that both screens show the same content in sync.

**Why this priority**: Without SSE subscription, Gaia only plays when the
operator manually presses the in-app Play button — the Aither web player and
Gaia are not synchronized.

**Independent Test**: Open both the Aither web player and the Gaia controller
for the same recording. Trigger `POST /api/recording/playback/play` from the
dashboard. Verify both players start playback within ~1 second of each other.

**Acceptance Scenarios**:

1. **Given** the Aither web player and Gaia controller are both open for the
   same recording, **When** `POST /api/recording/playback/play` is called,
   **Then** both players receive the `play` SSE command and begin playback
   within ~1 second of each other.
2. **Given** Gaia has chapters loaded (Spec 010), **When** the first `play`
   SSE command arrives, **Then** Gaia seeks to `chapters[0].start` before
   playing (matching Aither web player behavior).
3. **Given** both players are playing, **When** `POST /api/recording/playback/stop`
   is called, **Then** both players pause.
4. **Given** both players are playing, **When** a `seek` SSE command is
   dispatched, **Then** both players seek to the given position.

### User Story 2 — Reconnect on SSE Disconnect (Priority: P2)

As a seminar operator, I want Gaia to automatically reconnect to the Aither
SSE channel if the connection drops (network blip, Aither restart), so that
playback commands are not lost.

**Why this priority**: SSE connections are long-lived and can drop; without
reconnect, Gaia would miss playback commands until manually restarted.

**Independent Test**: Open Gaia for a recording, kill the Aither server,
restart it, then trigger `POST /play`. Verify Gaia reconnects and receives the
command.

**Acceptance Scenarios**:

1. **Given** Gaia is subscribed to SSE, **When** the connection drops,
   **Then** the monitor retries with backoff (0.5, 1, 2, 5 seconds) and
   reconnects automatically.
2. **Given** Gaia is reconnecting, **When** a `play` command is dispatched
   after reconnection, **Then** Gaia receives it and plays.

### Edge Cases

- What happens if the SSE connection is already open when `preparePlayer` is
  called again (e.g., recording change)? The monitor cancels the existing task
  and opens a new one for the new `assetId`.
- What happens if the Bearer token is expired? The SSE request returns 401;
  the monitor uses the existing `ServiceAuthorizationCoordinator` retry logic:
  cache invalidation → token renewal via `AitherServiceAuthenticator` → single
  retry. If the retry also fails (token truly invalid), the monitor stops
  retrying. No silent fallback — the operator must re-authenticate.
- What happens if `chapters` are not loaded yet when the first `play` command
  arrives? The view model plays from the current position (0) without initial
  seek — consistent with Spec 010's `chaptersNotGenerated` fallback.
- What happens if a `chapter-boundary` SSE event arrives? Gaia ignores it
  (Spec 010 handles boundaries via local time observer, not via SSE).
- What happens after 10 failed reconnect attempts? The monitor stops and the
  player shows „Aither nicht erreichbar — Sync offline“. The player remains
  manually operable (Play button works). The operator must reload the view to
  restart SSE sync.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Gaia MUST subscribe to Aither's SSE playback command channel
  (`GET /api/recording/events?recordingId=<assetId>`) when
  `VideoPlayerViewModel.preparePlayer()` succeeds.
- **FR-002**: The SSE request MUST include a Bearer `Authorization` header
  (Spec 05 `AitherServiceAuthenticator`).
- **FR-003**: Gaia MUST handle `play`, `stop`, and `seek` SSE commands by
  forwarding them to `VideoPlayerViewModel` (call `play()`, `pause()`, or
  `seek(to:)`).
- **FR-004**: On the first `play` command (whether via SSE or manual button),
  Gaia MUST seek to `chapters[0].start` (if chapters are loaded) before playing
  — matching Aither web player behavior (Aither Spec 011, FR-002) and Gaia
  Spec 010. This seek is **deterministic and position-independent**: it occurs
  regardless of the current playback position (even if the operator manually
  seeked ahead). The `hasPlayedOnce` flag prevents re-seeking on subsequent
  `play` commands (after pause/resume).
- **FR-005**: Gaia MUST ignore `chapter-boundary` SSE events (Spec 010 handles
  boundaries locally via `AVPlayer` time observer).
- **FR-006**: On SSE disconnect/error, the monitor MUST retry with backoff
  (0.5, 1, 2, 5 seconds — same pattern as `ConnectionStatusMonitor`).
- **FR-007**: When `VideoPlayerViewModel` is deinitialized or the player is
  torn down, the monitor MUST cancel the SSE task.
- **FR-008**: The monitor MUST NOT duplicate commands received via the manual
  Play button — SSE commands and manual button presses are independent
  triggers; both call `play()` (idempotent).

### Non-Functional Requirements

- **NFR-001**: The SSE subscription MUST NOT block the main actor — the
  monitor runs on a background task (`URLSession.bytes`); UI updates are
  dispatched to `@MainActor` via `Task { @MainActor in delegate.onPlay() }`
  per event (same pattern as `ConnectionStatusMonitor`).
- **NFR-002**: The monitor MUST be `Sendable`-safe (Swift 6 concurrency).
- **NFR-003**: Reconnect attempts MUST be capped (max 10 retries with backoff
  0.5, 1, 2, 5 seconds). After exhausting retries, the monitor MUST stop and
  the `VideoPlayerViewModel` MUST show a UI hint („Aither nicht erreichbar —
  Sync offline“). The player remains manually operable. The operator must
  reload the view to restart SSE sync.
- **NFR-004**: All new code MUST be covered by unit tests (Swift Testing /
  XCTest per existing `GaiaCoreTests` convention).

## API Reference

### Reused: `GET /api/recording/events` (Aither Spec 004)

Unchanged. Gaia opens an `EventSource`-style connection (via
`URLSession.bytes(for:)`) with `Accept: text/event-stream` and Bearer auth.

**Event format** (existing, unchanged):
```
event: command
data: {"action":"play"}
```

## Data Model

No new data models. Reuses `ChapterSummary` (Spec 010) and the existing SSE
command shapes (`play`, `stop`, `seek`, `chapter-boundary`).

### New Component: `PlaybackCommandMonitor`

```swift
@MainActor
protocol PlaybackCommandDelegate: AnyObject {
  func onPlay()
  func onStop()
  func onSeek(position: Double)
}

actor PlaybackCommandMonitor {
  init(baseURL: URL, recordingId: String, authenticator: AitherServiceAuthenticator)
  func start(delegate: PlaybackCommandDelegate) async
  func stop() async
}
```

**Thread-Safety**: The monitor runs on a background task. Each SSE event
wraps the delegate callback in `Task { @MainActor in ... }` to hop to the
main actor (same pattern as `ConnectionStatusMonitor`). The delegate protocol
remains synchronous (`@MainActor`-isolated); no `async` methods needed.

## Testing Strategy

- **Unit tests** (Swift Testing):
  - `PlaybackCommandMonitor` SSE parsing: `play`, `stop`, `seek` events.
  - Reconnect backoff sequence.
  - Delegate callback dispatch.
  - 401 auth failure handling (stop retrying).
- **Integration tests**:
  - `VideoPlayerViewModel` + mock `PlaybackCommandMonitor`: first `play`
    command triggers initial seek to `chapters[0].start`.
  - `stop` and `seek` commands forwarded correctly.
- **E2E** (manual): Aither web player + Gaia controller both open, trigger
  `POST /play` from dashboard, verify both play in sync.

## Open Questions

- None currently. Architecture reuses existing `ConnectionStatusMonitor`
  pattern; Aither requires no changes.
