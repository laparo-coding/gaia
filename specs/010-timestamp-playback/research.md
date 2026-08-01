# Phase 0 Research: Timestamp Playback

**Spec Reference**: [spec.md](./spec.md)
**Date**: 2026-07-19

---

## R1. MUX iOS Player SDK

**Decision**: Use the native **`AVPlayer`** (AVFoundation) to play the MUX HLS
playback URL resolved via Aither's `GET /api/recording/stream/[id]` endpoint.
No third-party MUX player SDK dependency is introduced.

**Rationale**:
- The official `muxinc/mux-player-swift` SwiftPM package has an internal
  platform conflict (declares macOS 10.13 but depends on `GCDWebServer` which
  requires macOS 10.15), which blocks `swift build` from the command line — a
  Constitution III requirement (VS Code-First Swift Toolchain Discipline).
- `AVPlayer` is the canonical iOS/iPadOS video player and natively supports:
  - Loading HLS streams by URL (`AVPlayerItem(url:)`)
  - Programmatic seek (`player.seek(to:)`)
  - Current position observation (`player.currentTime()`, periodic
    `addTimeObserver` / Combine-friendly async sequence)
- MUX delivers video as standard HLS (`.m3u8`) via its CDN; `AVPlayer` plays
  HLS natively without any MUX-specific SDK.
- MUX Data monitoring is not required for this feature (Spec 010 is about
  chapter playback, not analytics); if monitoring is needed later, it can be
  added via the separate `MuxCore` stats SDK without the player SDK.
- This keeps the dependency surface minimal (Constitution V: minimal public
  surface area) and avoids the platform conflict.

**Alternatives considered**:
- **`muxinc/mux-player-swift` SwiftPM package** — rejected due to the
  macOS 10.13/10.15 platform conflict that breaks `swift build` from the
  command line (Constitution III violation).
- **HTML5 `<video>` via WKWebView** — Aither's web player uses this, but Gaia
  is a native SwiftUI iPad app; native `AVPlayer` gives better seek performance
  (NFR-001 ≤ 200 ms) and native UI integration for the "Next Chapter" button.

---

## R2. MUX Asset ID → Playback URL Resolution

**Decision**: Gaia resolves the playback URL via Aither's
`GET /api/recording/stream/[id]` endpoint, which returns an HTTP 302 redirect to
the MUX CDN URL for the chaptered asset. Gaia follows the redirect to obtain the
`URL` and passes it to the native AVPlayer (or loads by playback id if Aither
exposes it in a future extension of `GET /api/recording/chapters/[id]`).

**Rationale**:
- Aither's Spec 010 FR-017 already defines `GET /api/recording/stream/[id]` as
  the canonical streaming endpoint (MUX CDN redirect, Range support, falls back
  to raw asset if no chaptered variant).
- AVPlayer can load by URL; loading by URL via the stream endpoint avoids
  coupling Gaia to the CDN's internal asset id format.
- The stream endpoint is already authenticated via the same Bearer contract
  (Spec 005), so no additional auth surface is needed.

**Alternatives considered**:
- **Extend `GET /api/recording/chapters/[id]` to include `playbackUrl`** —
  cleaner (one call), but requires an Aither-side contract change. Deferred to a
  future optimization; for now Gaia makes two calls (chapters + stream).
- **Hard-code MUX CDN URL pattern** — rejected; violates Constitution VI
  (no placeholder/runtime-config assumptions) and couples Gaia to MUX internals.

---

## R3. Chapter List Caching

**Decision**: Short-lived in-memory cache, per `assetId`, TTL ≤ 60 seconds,
invalidated immediately on successful regeneration (`POST` returns `200`).
Cache lives in `PlaybackClient` (a `Sendable` struct with an actor-isolated
cache store).

**Rationale**:
- Chapters rarely change during a viewing session (regeneration is explicit and
  infrequent).
- 60s TTL matches the existing `DashboardCache` pattern (Spec 008/009) for
  consistency.
- Invalidation on regeneration success (FR-007) ensures the player always uses
  fresh chapters after an explicit regenerate action.
- No persistent storage needed (chapters are re-fetchable from Aither).

**Alternatives considered**:
- **No cache (always fetch)** — simpler but adds a network round-trip on every
  player load; rejected for UX latency.
- **Persistent cache (SQLite/SwiftData)** — overkill for ephemeral chapter data;
  rejected (Constitution: minimal storage surface).

---

## R4. Player Position Observation

**Decision**: Use `AVPlayer`'s periodic time observer
(`addPeriodicTimeObserver(forInterval:queue:using:)`) to observe current
playback position. The `VideoPlayerViewModel` (`@MainActor`) subscribes to
position updates and recomputes the "Next Chapter" button enabled state. On
button press, the view model calls `player.seek(to: nextChapter.start)`
directly.

**Rationale**:
- `AVPlayer` exposes position via periodic time observers, which integrate
  cleanly with SwiftUI's `@MainActor` observation.
- Position updates drive the button's enabled state (FR-004: disabled in last
  chapter) without polling.
- The seek itself is a direct `AVPlayer` seek (near-instantaneous, NFR-001).

**Alternatives considered**:
- **Poll `AVPlayer.currentTime()` on a timer** — works but less efficient than
  the built-in periodic observer; rejected.
- **Only compute on button press** — doesn't update the disabled state as the
  user plays through the last chapter; rejected (FR-004 requires reactive
  disablement).

---

## R5. Regeneration Failure UX

**Decision**: Map Aither's error codes to a structured `PlaybackError` enum with
user-facing German messages (informal "Du" per Hemera convention). The
"Regenerate chapters" control shows a failure overlay with the error message and
a retry action. The "Next Chapter" button remains disabled during regeneration
and on failure.

| Aither Code | HTTP | `PlaybackError` case | German UI message |
|-------------|------|---------------------|------------------|
| `RECORDING_NOT_FOUND` | 404 | `recordingNotFound` | "Aufnahme nicht gefunden." |
| `FFMETADATA_NOT_FOUND` | 404 | `ffmetadataNotFound` | "Kapitel-Metadaten nicht gefunden." |
| `CHAPTERS_NOT_GENERATED` | 404 | `chaptersNotGenerated` | "Kapitel noch nicht generiert. Bitte zuerst regenerieren." |
| `RECORDING_IN_PROGRESS` | 409 | `recordingInProgress` | "Aufnahme läuft noch. Regeneration später erneut versuchen." |
| `FFMETADATA_INVALID` | 422 | `ffmetadataInvalid` | "Kapitel-Metadaten ungültig." |
| `REMUX_FAILED` | 502 | `remuxFailed` | "Video-Regeneration fehlgeschlagen. Erneut versuchen?" |
| `BLOB_STORAGE_UNAVAILABLE` | 503 | `blobStorageUnavailable` | "Speicher vorübergehend nicht verfügbar. Erneut versuchen?" |
| `UNAUTHORIZED` | 401 | `unauthorized` | "Nicht autorisiert." |
| `FORBIDDEN` | 403 | `forbidden` | "Keine Berechtigung für diese Aktion." |

**Rationale**:
- Constitution VI requires structured, actionable errors.
- German informal "Du" matches the Hemera communication style convention.
- Retry action for transient failures (`502`, `503`) follows the soft-fail
  pattern from Spec 009.

**Alternatives considered**:
- **Generic error message for all failures** — rejected (Constitution VI:
  errors must be attributable and actionable).
- **English messages** — rejected (Hemera convention is German informal).

---

## R6. Aither Contract Reuse

**Decision**: Gaia consumes Aither's already-implemented Spec 010 endpoints
exactly as defined (verified on branch `010-chapters-in-video`):

- `GET /api/recording/chapters/[id]` → `ChapterListResponse` (chapter list,
  seconds-based, sourced from MUX embedded chapters).
- `POST /api/recording/chapters/[id]` → `ChapterRegenerationResult`
  (synchronous regeneration).
- `GET /api/recording/stream/[id]` → MUX CDN redirect (playback URL).

No Gaia-side contract changes are needed. Gaia is a pure consumer.

**Rationale**:
- Aither's Spec 010 is already implemented and validated (T060–T064, 2026-07-19).
- Reusing the existing contract avoids cross-service coordination overhead.
- The hybrid chapter-source decision (Q1) aligns: JSON manifest primary,
  embedded MUX metadata as source of truth.

**Alternatives considered**:
- **Propose Aither contract changes** — rejected; Aither's contract already
  satisfies Gaia's needs.

---

## R7. Swift 6 / SwiftUI Best Practices for Video Player

**Decision**:
- `VideoPlayerViewModel` is `@MainActor final class ObservableObject` (SwiftUI
  convention); player state (current position, ready state) is `@Published`.
- `PlaybackClient` is a `Sendable` struct (network client, no UI state).
- `ChapterSeekLogic` is a pure function: `(chapters: [ChapterSummary], currentPosition: Double) -> ChapterSummary?` — fully testable without UI.
- The player view wraps `AVPlayer` in a SwiftUI `UIViewRepresentable` /
  `UIViewControllerRepresentable` using `AVPlayerViewController` (or the
  SwiftUI `VideoPlayer` view on iOS 16+).
- Seek is called on the main actor; `AVPlayer.seek` handles the underlying
  seek off-main.

**Rationale**:
- Constitution IV: `Sendable` boundaries, `@MainActor` for UI, pure logic for
  testability.
- Pure `ChapterSeekLogic` enables fast unit tests for the position-relative
  next-chapter computation (FR-002, FR-004) without a running player.

**Alternatives considered**:
- **Put seek logic in the view model** — harder to test in isolation; rejected.
- **Make the player a `Sendable` actor** — conflicts with SwiftUI's
  `@MainActor` `ObservableObject` pattern; rejected.

---

## Summary of Decisions

| # | Topic | Decision |
|---|-------|----------|
| R1 | MUX player SDK | Native `AVPlayer` (MUX HLS URL via stream endpoint) |
| R2 | Playback URL | Resolve via `GET /api/recording/stream/[id]` (MUX CDN redirect) |
| R3 | Chapter cache | In-memory, per-assetId, TTL ≤ 60s, invalidate on regeneration |
| R4 | Position observation | `AVPlayer` periodic time observer + `@MainActor` view model |
| R5 | Failure UX | Structured `PlaybackError` + German messages + retry action |
| R6 | Aither contract | Reuse existing Spec 010 endpoints unchanged |
| R7 | Swift 6 patterns | `@MainActor` VM, `Sendable` client, pure seek logic, native `AVPlayer` |

All NEEDS CLARIFICATION resolved. No outstanding unknowns.
