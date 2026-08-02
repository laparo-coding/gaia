# Contract: SSE Playback Command Channel

**Phase**: 1 | **Date**: 2026-08-02 | **Spec**: [spec.md](spec.md)

This contract describes the SSE event format consumed by Gaia's `PlaybackCommandMonitor` from Aither's existing endpoint `GET /api/recording/events` (Aither Spec 004). The endpoint is unchanged — this contract documents the consumer-side expectations.

## Endpoint

```
GET /api/recording/events?recordingId=<assetId>
Authorization: Bearer <token>
Accept: text/event-stream
```

## Event Format

Aither sends Server-Sent Events in the standard `text/event-stream` format. Each event has an `event:` field and a `data:` field.

### Connected Event

```
event: connected
data: {"recordingId":"rec_2026-07-13T10-30-00Z"}
```

### Command Events

```
event: command
data: {"action":"play"}

event: command
data: {"action":"stop"}

event: command
data: {"action":"seek","position":12.5}

event: command
data: {"action":"chapter-boundary","chapterId":0,"nextChapterId":1}
```

### Heartbeat

```
: heartbeat
```

(Comment line, no event — keeps connection alive through proxies.)

## Command Actions

| Action | Payload | Gaia Behavior |
|--------|---------|---------------|
| `play` | `{"action":"play"}` | First play: seek to `chapters[0].start` then `player.play()`. Subsequent: `player.play()` only. |
| `stop` | `{"action":"stop"}` | `player.pause()` |
| `seek` | `{"action":"seek","position":N}` | `player.seek(to: CMTime(seconds: N))` |
| `chapter-boundary` | `{"action":"chapter-boundary","chapterId":N,"nextChapterId":N?}` | `player.pause()` (sync with Aither web player) |

## Error Handling

| HTTP Status | Behavior |
|-------------|----------|
| 200 | SSE stream opens; parse events. |
| 401 | Token renewal via `ServiceAuthorizationCoordinator` → single retry. If retry fails, stop. |
| 404 | Recording not found — stop retrying (no reconnect). |
| 500+ | Reconnect with backoff (max 10 attempts). |

## Reconnect Behavior

| Attempt | Delay |
|---------|-------|
| 1 | 0.5s |
| 2 | 1s |
| 3 | 2s |
| 4 | 5s |
| 5–10 | 5s (capped) |
| >10 | Stop, show "Aither nicht erreichbar — Sync offline" |

## Backward Compatibility

- Aither's endpoint is unchanged (Spec 004).
- Gaia is a new SSE client — no impact on existing clients (Aither web player).
- `chapter-boundary` events are already emitted by Aither (Spec 010); Gaia now consumes them (previously ignored).
