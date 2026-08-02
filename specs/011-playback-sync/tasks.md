# Tasks: Playback Sync

**Input**: Design documents from `/specs/011-playback-sync/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/sse-playback-command.contract.md, quickstart.md
**Tests**: TDD mandatory per Constitution Principle II — unit tests first, then implementation.

**Organization**: Tasks grouped by user story (US1: Sync Playback, US2: Reconnect) with shared foundational phase.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story this task belongs to (US1, US2, SHARED)
- File paths are relative to repository root (`/Users/Andreas/GitHub/gaia/`)

---

## Phase 1: Foundational (Shared Infrastructure)

**Purpose**: `PlaybackCommandDelegate` protocol + `PlaybackCommandMonitor` actor reused by all user stories.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Tests (write first, must fail)

- [ ] T001 [P] [SHARED] Unit test for `PlaybackCommandDelegate` protocol conformance in `Tests/GaiaCoreTests/Playback/PlaybackCommandDelegateTests.swift`: verify a minimal `@MainActor` mock conforming to the protocol receives `onPlay`, `onStop`, `onSeek(position:)`, `onChapterBoundary` callbacks.
- [ ] T002 [P] [SHARED] Unit test for `PlaybackCommandMonitor` SSE parsing in `Tests/GaiaCoreTests/Playback/PlaybackCommandMonitorTests.swift`: parse `play`, `stop`, `seek`, `chapter-boundary` events from mock SSE stream; verify delegate callbacks dispatched via `Task { @MainActor in }`.

### Implementation

- [ ] T003 [SHARED] Create `Sources/GaiaCore/Playback/PlaybackCommandDelegate.swift` with `@MainActor protocol PlaybackCommandDelegate: AnyObject` defining `onPlay()`, `onStop()`, `onSeek(position: Double)`, `onChapterBoundary()`, `onSyncOffline()` (depends on T001).
- [ ] T004 [SHARED] Create `Sources/GaiaCore/Playback/PlaybackCommandMonitor.swift` with `actor PlaybackCommandMonitor`: `init(baseURL:recordingId:authenticator:)`, `start(delegate:) async`, `stop() async`. Uses `URLSession.bytes(for:)` for SSE streaming, `HTTPChunkedTransfer` for line parsing, `AitherServiceAuthenticator` for Bearer header. Parses `event: command` + `data:` JSON. Dispatches to delegate via `Task { @MainActor in }` (depends on T002, T003).

**Checkpoint**: Delegate protocol + monitor actor ready — user story implementation can begin.

---

## Phase 2: User Story 1 — Gaia Plays in Sync with Aither Web Player (Priority: P1) 🎯 MVP

**Goal**: Gaia subscribes to SSE, receives `play`/`stop`/`seek`/`chapter-boundary` commands, and forwards them to `VideoPlayerViewModel`.

**Independent Test**: Open both players for same recording, trigger `POST /play`, verify both play in sync within ~1 second.

### Tests for User Story 1 (write first, must fail)

- [ ] T010 [P] [US1] Integration test in `Tests/GaiaCoreTests/Playback/VideoPlayerViewModelPlaybackSyncTests.swift`: `VideoPlayerViewModel` conforms to `PlaybackCommandDelegate`; `onPlay()` triggers initial seek to `chapters[0].start` on first call (if chapters loaded), then `player.play()`; `hasPlayedOnce` prevents re-seek on subsequent calls.
- [ ] T011 [P] [US1] Integration test in `Tests/GaiaCoreTests/Playback/VideoPlayerViewModelPlaybackSyncTests.swift`: `onStop()` calls `player.pause()`; `onSeek(position:)` calls `player.seek(to:)`; `onChapterBoundary()` calls `player.pause()`.
- [ ] T012 [P] [US1] Integration test in `Tests/GaiaCoreTests/Playback/VideoPlayerViewModelPlaybackSyncTests.swift`: `preparePlayer()` starts `PlaybackCommandMonitor`; deinit stops it.

### Implementation for User Story 1

- [ ] T013 [US1] Extend `app/controller/VideoPlayerViewModel.swift`: conform to `PlaybackCommandDelegate`; add `onPlay()` (initial seek to `chapters[0].start` if `!hasPlayedOnce && chapters.count > 0`, set `hasPlayedOnce = true`, call `play()`), `onStop()` (call `pause()`), `onSeek(position:)` (seek `AVPlayer`), `onChapterBoundary()` (call `pause()`). Start `PlaybackCommandMonitor` in `preparePlayer()` after player is ready; stop in `pause()`/deinit (depends on T004, T010, T011, T012).

**Checkpoint**: User Story 1 fully functional — Gaia plays in sync with Aither web player.

---

## Phase 3: User Story 2 — Reconnect on SSE Disconnect (Priority: P2)

**Goal**: Monitor reconnects with backoff on disconnect; stops after 10 attempts with UI hint.

**Independent Test**: Kill Aither, restart, trigger `POST /play` — verify Gaia reconnects and plays.

### Tests for User Story 2 (write first, must fail)

- [ ] T020 [P] [US2] Unit test in `Tests/GaiaCoreTests/Playback/PlaybackCommandMonitorTests.swift`: reconnect backoff sequence (0.5, 1, 2, 5, 5, ... seconds); max 10 attempts; after 10, stops and notifies delegate of sync-offline.
- [ ] T021 [P] [US2] Unit test in `Tests/GaiaCoreTests/Playback/PlaybackCommandMonitorTests.swift`: 401 handling — `ServiceAuthorizationCoordinator` retry (cache invalidation → token renewal → single retry); if retry fails, stop.
- [ ] T022 [P] [US2] Integration test in `Tests/GaiaCoreTests/Playback/VideoPlayerViewModelPlaybackSyncTests.swift`: sync-offline state shows UI hint "Aither nicht erreichbar — Sync offline"; player remains manually operable.

### Implementation for User Story 2

- [ ] T023 [US2] Extend `Sources/GaiaCore/Playback/PlaybackCommandMonitor.swift`: implement reconnect with backoff `[0.5, 1, 2, 5]` seconds, max 10 attempts; on exhaustion, call `delegate.onSyncOffline()`. Implement 401 handling via `ServiceAuthorizationCoordinator` (depends on T004, T020, T021).
- [ ] T024 [US2] Extend `app/controller/VideoPlayerViewModel.swift`: implement `onSyncOffline()` — set `syncOffline` published state; `VideoPlaybackCard` shows hint text when `syncOffline == true` (depends on T013, T022, T023).

**Checkpoint**: User Story 2 fully functional — Gaia reconnects and shows hint on exhaustion.

---

## Phase 4: Integration & Documentation

**Purpose**: End-to-end validation and documentation.

### Integration Tests

- [ ] T030 [P] [INTEG] Manual E2E: both players open, trigger `POST /play`, verify sync within ~1 second; trigger `POST /stop`, verify both pause; trigger seek, verify both seek.
- [ ] T031 [P] [INTEG] Manual E2E: kill Aither, restart, trigger `POST /play` — verify Gaia reconnects and plays; kill Aither for >10 cycles — verify "Sync offline" hint.

### Documentation

- [ ] T040 [P] [DOCS] Update `specs/011-playback-sync/spec.md` Status field from "Draft" to "Implemented" after all tasks complete.

**Checkpoint**: Feature complete — all user stories validated end-to-end.
