# Research: Playback Sync

**Phase**: 0 | **Date**: 2026-08-02 | **Spec**: [spec.md](spec.md)

All technical unknowns are resolved by reusing existing Gaia infrastructure (`ConnectionStatusMonitor` SSE pattern, `ServiceAuthorizationCoordinator` 401-retry, `AitherServiceAuthenticator` Bearer auth). No new external dependencies.

## Research Tasks

### 1. SSE Client Pattern — ConnectionStatusMonitor Reuse

**Decision**: `PlaybackCommandMonitor` is a direct architectural analog of `ConnectionStatusMonitor`, adapted for playback commands instead of dashboard status.

**Rationale**: `ConnectionStatusMonitor` already implements `URLSession.bytes(for:)` streaming, `data:` line parsing, `Accept: text/event-stream` header, and reconnect with backoff (`[0.5, 1, 2, 5]` seconds). The same pattern applies 1:1 to `/api/recording/events`.

**Differences from ConnectionStatusMonitor**:
- Different endpoint: `/api/recording/events?recordingId=<id>` (not `/api/dashboard/status/events`)
- Different event types: `command` events with `play`/`stop`/`seek`/`chapter-boundary` actions (not status events)
- Different delegate: `PlaybackCommandDelegate` (not `ConnectionStatusDelegate`)
- 401 handling: uses `ServiceAuthorizationCoordinator` retry (not just reconnect)

**Alternatives Rejected**:
- Third-party SSE library: Rejected — `URLSession.bytes` is sufficient and already proven in `ConnectionStatusMonitor`.
- WebSocket: Rejected — Aither's endpoint is SSE, not WebSocket.

### 2. 401 Token Renewal — ServiceAuthorizationCoordinator Reuse

**Decision**: Use existing `ServiceAuthorizationCoordinator.executeAuthorizedRequest` 401-retry logic for the initial SSE connection.

**Rationale**: `ServiceAuthorizationCoordinator` already implements: 401 detection → cache invalidation → `AitherServiceAuthenticator.authorize()` re-call → single retry. The `AitherServiceAuthenticator` token provider reads `AITHER_SYNC_TOKEN` from environment. This is the same auth flow used by `PlaybackClient` and all other Aither API clients.

**Limitation**: The retry logic applies only to the initial HTTP request (connection setup). Mid-stream token expiry (token expires while SSE is open) is not handled — the SSE connection would drop, triggering a normal reconnect, which would then use the fresh token. This is acceptable.

**Alternatives Rejected**:
- Silent fallback (no retry): Rejected — operator would lose sync without feedback.
- Manual re-auth UI: Rejected — automatic renewal is sufficient for static token.

### 3. Thread-Safety — Task @MainActor per Event

**Decision**: Each SSE event wraps the delegate callback in `Task { @MainActor in delegate.onPlay() }`.

**Rationale**: `ConnectionStatusMonitor` uses the same pattern. The monitor runs on a background task (`URLSession.bytes` is async); only the delegate callback hops to `@MainActor`. Swift 6 safe (canonical actor hop), NFR-001 satisfied (background task not blocked), `@MainActor protocol` pattern preserved.

**Alternatives Rejected**:
- `MainActor.assumeIsolated`: Unsafe — would crash if monitor is not on Main-Actor.
- Async delegate methods: Breaks existing `@MainActor protocol` pattern; all implementers would need `async`.

### 4. chapter-boundary Handling — Pause for Sync

**Decision**: Gaia pauses on `chapter-boundary` SSE events (`player.pause()`), matching Aither web player Spec 010 FR-015.

**Rationale**: The core goal of this spec is sync. If Aither pauses at chapter end and Gaia continues, they are out of sync. The `chapter-boundary` event is a shared command ("pause now"), not position sync — it's in scope ("synchronizes start/stop/seek commands"). The local `AVPlayer` time observer (Spec 010) remains for local boundary detection; the SSE event is an additional sync trigger.

**Alternatives Rejected**:
- Ignore `chapter-boundary` (original FR-005): Sync drift at chapter end — violates core spec goal.
- Local pause only (no SSE): Each player uses its own clock → slightly asynchronous.

### 5. Reconnect Exhaustion — Stop + UI Hint

**Decision**: After 10 failed reconnect attempts, the monitor stops and `VideoPlayerViewModel` shows "Aither nicht erreichbar — Sync offline".

**Rationale**: Operator feedback (vs. silent stop), no endless retries (battery/network), consistent with `ConnectionStatusMonitor` (also has capped retries). Player remains manually operable.

**Alternatives Rejected**:
- Infinite exponential backoff: Battery/network drain on iPad.
- Silent stop: Operator wonders why commands don't arrive.

### 6. Initial Seek — Deterministic chapters[0].start

**Decision**: On the first `play` command (SSE or manual), Gaia always seeks to `chapters[0].start`, regardless of current position. `hasPlayedOnce` prevents re-seeking.

**Rationale**: Sync consistency with Aither web player (Aither Spec 011 FR-002 also always seeks to `chapters[0].start` on first play). If Gaia behaves differently, both players are not synchronized.

**Alternatives Rejected**:
- Only seek if position is 0: State-dependent, diverges from Aither.
- Never seek via SSE: Diverges from Aither, loses sync.

### 7. Existing Infrastructure Reuse — No New Dependencies

**Decision**: Reuse all existing infrastructure: `ConnectionStatusMonitor` (SSE pattern), `HTTPChunkedTransfer` (chunked parsing), `AitherServiceAuthenticator` (Bearer auth), `ServiceAuthorizationCoordinator` (401 retry), `ChapterSeekLogic` (initial seek), `VideoPlayerViewModel` (existing chapter list).

**Rationale**: No new npm/SwiftPM dependencies, no new external services. All infrastructure is already implemented and tested in prior specs (005, 008, 009, 010).
