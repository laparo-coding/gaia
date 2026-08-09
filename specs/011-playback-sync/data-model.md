# Data Model: Playback Sync

**Phase**: 1 | **Date**: 2026-08-02 | **Spec**: [spec.md](spec.md)

No new data models. This feature reuses `ChapterSummary` (Spec 010) and the existing SSE command shapes. The new components are a delegate protocol and an actor.

## New Components

### PlaybackCommandDelegate

**Purpose**: `@MainActor` protocol that `VideoPlayerViewModel` conforms to. The `PlaybackCommandMonitor` calls these methods via `Task { @MainActor in }` per SSE event.

```swift
@MainActor
protocol PlaybackCommandDelegate: AnyObject, Sendable {
  /// Called when a `play` SSE command is received.
  func onPlay()
  /// Called when a `stop` SSE command is received.
  func onStop()
  /// Called when a `seek` SSE command is received.
  func onSeek(position: Double)
  /// Called when a `chapter-boundary` SSE command is received.
  func onChapterBoundary()
  /// Called when the monitor goes offline after exhausting auth retries.
  func onSyncOffline()
}
```

**Thread-Safety**: The protocol is `@MainActor`-isolated. The monitor (an `actor`) wraps each callback in `Task { @MainActor in delegate.onPlay() }` to hop from the background SSE task to the main actor.

### PlaybackCommandMonitor

**Purpose**: `actor` that subscribes to Aither's SSE playback command channel, parses `event: command` messages, and forwards actions to the delegate.

```swift
actor PlaybackCommandMonitor {
  /// Creates a monitor for the given Aither base URL and recording ID.
  init(baseURL: URL, recordingId: String, authenticator: AitherServiceAuthenticator)

  /// Starts the SSE subscription. The delegate is called on the main actor.
  func start(delegate: PlaybackCommandDelegate) async

  /// Stops the SSE subscription and cancels the background task.
  func stop() async
}
```

**Lifecycle**:
1. `start(delegate:)` opens `URLSession.bytes(for:)` to `GET /api/recording/events?recordingId=<id>` with `Accept: text/event-stream` and Bearer `Authorization` header.
2. For each `event: command` line, parse the `data:` JSON payload: `{"action":"play"}`, `{"action":"stop"}`, `{"action":"seek","position":N}`, `{"action":"chapter-boundary","chapterId":N,"nextChapterId":N?}`.
3. Dispatch to delegate via `Task { @MainActor in ... }`.
4. On error/disconnect, retry with backoff `[0.5, 1, 2, 5]` seconds, max 10 attempts.
5. On 401, use `ServiceAuthorizationCoordinator` retry: invalidate cache → renew token → single retry.
6. After 10 failed attempts, stop and notify delegate (new method `onSyncOffline()` or state flag).
7. `stop()` cancels the SSE task.

### SSE Command Shapes (Reused from Aither)

```swift
enum PlaybackSSECommand {
  case play
  case stop
  case seek(position: Double)
  case chapterBoundary(chapterId: Int, nextChapterId: Int?)
}
```

Parsed from Aither's `event: command` SSE format:
```
event: command
data: {"action":"play"}

event: command
data: {"action":"seek","position":12.5}

event: command
data: {"action":"chapter-boundary","chapterId":0,"nextChapterId":1}
```

## Reused Entities (No Changes)

- `ChapterSummary` (Spec 010): `{ id, start, end, title }` — used for initial seek to `chapters[0].start`.
- `ChapterSeekLogic` (Spec 010): not directly used here, but `VideoPlayerViewModel` uses it for Next Chapter button.
- `AitherServiceAuthenticator` (Spec 005): provides Bearer token.
- `ServiceAuthorizationCoordinator` (Spec 005): provides 401-retry logic.
- `ConnectionStatusMonitor` (Spec 008): pattern reference (not modified).
- `HTTPChunkedTransfer` (Spec 008): SSE line parsing helper (reused).
