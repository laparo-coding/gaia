# Quickstart: Playback Sync

**Phase**: 1 | **Date**: 2026-08-02 | **Spec**: [spec.md](spec.md)

## Prerequisites

- Gaia building and running on iPadOS simulator or device (`swift run` or Xcode)
- Aither running on `localhost:3000` (`npm run dev`)
- A chaptered recording exists (regenerated via `POST /api/recording/chapters/[id]`)
- `AITHER_SYNC_TOKEN` environment variable set on Gaia

## Validation 1: PlaybackCommandMonitor Unit Tests

```bash
swift test --filter PlaybackCommandMonitorTests
```

**Expected**: All tests pass (SSE parsing for play/stop/seek/chapter-boundary, reconnect backoff, 401 handling, delegate dispatch).

## Validation 2: VideoPlayerViewModel Integration Tests

```bash
swift test --filter VideoPlayerViewModelPlaybackSyncTests
```

**Expected**: All tests pass (first play seeks to `chapters[0].start`, stop pauses, seek seeks, chapter-boundary pauses, reconnect exhaustion shows offline hint).

## Validation 3: Manual E2E Test

1. Open the Aither web player at `http://localhost:3000/recording/player/<recording-id>`.
2. Open the Gaia controller app for the same recording.
3. Trigger `POST /api/recording/playback/play` from the dashboard (or curl):
   ```bash
   curl -X POST http://localhost:3000/api/recording/playback/play \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <token>" \
     -d '{"recordingId":"<recording-id>"}'
   ```
4. Verify both players start playback within ~1 second of each other.
5. Verify Gaia seeks to `chapters[0].start` on first play.
6. Trigger `POST /api/recording/playback/stop` — verify both pause.
7. Kill Aither, restart it, trigger `POST /play` — verify Gaia reconnects and plays.
8. Kill Aither for >10 reconnect cycles — verify Gaia shows "Aither nicht erreichbar — Sync offline".
