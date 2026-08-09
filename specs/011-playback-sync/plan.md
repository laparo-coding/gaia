# Implementation Plan: Playback Sync

**Branch**: `011-playback-sync` | **Date**: 2026-08-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/011-playback-sync/spec.md`

## Summary

Gaia subscribes to Aither's SSE playback command channel (`/api/recording/events`) so that a single `POST /api/recording/playback/play` starts both the Aither web player and the Gaia controller simultaneously. A new `PlaybackCommandMonitor` (analog to `ConnectionStatusMonitor`) listens for `play`/`stop`/`seek`/`chapter-boundary` SSE commands and forwards them to `VideoPlayerViewModel`. On the first `play` command, Gaia seeks to `chapters[0].start` (matching Aither web player behavior). On `chapter-boundary`, Gaia pauses (matching Aither Spec 010 FR-015). Reconnect with backoff (max 10 retries), 401 token renewal via `ServiceAuthorizationCoordinator`, `Task { @MainActor in }` per event for thread-safety. No Aither changes needed.

## Technical Context

**Language/Version**: Swift 6.x (package targets), Swift 6.1 manifest
**Primary Dependencies**: SwiftPM, Foundation (`URLSession`), existing `GaiaCore` modules (`Authentication`, `Dashboard`, `Playback`), `AVFoundation` (`AVPlayer`)
**Storage**: No new storage. SSE connection is transient (in-memory). Chapter list already held by `VideoPlayerViewModel` (Spec 010).
**Testing**: Swift Testing / XCTest per existing `GaiaCoreTests` convention
**Target Platform**: iPadOS Controller app (landscape mode)
**Project Type**: swift-package with Apple-platform app target (`GaiaControllerApp`)
**Editor Workflow**: VS Code + `swiftlang.swift-vscode` + LLDB DAP; tasks `swift: Build Debug`, `swift: Test`, `swift: Format`, `swift: Lint`
**Performance Goals**: SSE event → delegate callback ≤ 100 ms (local, no network); sync drift ≤ 1 second between Gaia and Aither web player
**Constraints**: Swift 6 `Sendable`-safe; `@MainActor` delegate pattern; max 10 reconnect retries; Bearer auth via Spec 005; no Aither changes
**Scale/Scope**: ~250–350 lines new/modified code (1 new `PlaybackCommandMonitor` actor, 1 new delegate protocol, `VideoPlayerViewModel` extension, tests)

## Constitution Check

**GATE RESULT: PASS** — All principles satisfied. No violations require justification.

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Delivery | ✅ PASS | spec.md written; clarifications resolved (5 Q&As); this plan; tasks to follow. |
| II. Test-First Development | ✅ PASS | New `PlaybackCommandMonitor` + delegate + ViewModel extension require unit + integration tests. TDD cycle enforced. |
| III. VS Code-First Swift Toolchain | ✅ PASS | SwiftPM build, `swift: Build Debug`, `swift: Test` tasks remain working. No Xcode-only assets. |
| IV. Swift API Design, Concurrency, Type Safety | ✅ PASS | `actor PlaybackCommandMonitor` (Sendable-safe), `@MainActor` delegate protocol, `Task { @MainActor in }` per event, no force-unwrapping, structured error types. Swift 6 concurrency checking enabled. |

## Project Structure

### Documentation (this feature)

```text
specs/011-playback-sync/
├── spec.md              # Feature specification (with 5 clarifications)
├── plan.md              # This file
├── research.md          # Phase 0 output — technical unknowns resolved
├── data-model.md        # Phase 1 output — delegate protocol, monitor actor
├── quickstart.md        # Phase 1 output — validation steps
├── contracts/
│   └── sse-playback-command.contract.md  # Phase 1 output — SSE event contract
└── tasks.md             # Phase 2 output — task breakdown
```

### Source Code (repository root)

```text
Sources/
├── GaiaCore/
│   ├── Playback/
│   │   ├── PlaybackCommandMonitor.swift   # NEW: SSE client actor for playback commands
│   │   ├── PlaybackCommandDelegate.swift  # NEW: @MainActor delegate protocol
│   │   ├── ChapterSeekLogic.swift         # EXISTING (Spec 010): reused for initial seek
│   │   ├── PlaybackClient.swift           # EXISTING: unchanged
│   │   └── ...
│   ├── Dashboard/
│   │   ├── ConnectionStatusMonitor.swift   # EXISTING: pattern reference (not modified)
│   │   └── HTTPChunkedTransfer.swift       # EXISTING: reused for SSE parsing
│   └── Authentication/
│       └── AitherServiceAuthenticator.swift # EXISTING: reused for Bearer auth
├── GaiaControllerApp/
│   └── app/controller/
│       └── VideoPlayerViewModel.swift     # EXTENDED: start/stop monitor, delegate conformance, deinit cleanup
└── ...

Tests/
├── GaiaCoreTests/
│   └── Playback/
│       ├── PlaybackCommandMonitorTests.swift  # NEW: unit tests
│       └── PlaybackCommandDelegateTests.swift # NEW: delegate conformance tests
└── ...
```

**Structure Decision**: SwiftPM single-package (existing Gaia structure). New `PlaybackCommandMonitor` and `PlaybackCommandDelegate` in `Sources/GaiaCore/Playback/` follow existing module convention. `VideoPlayerViewModel` extension localized to `app/controller/`. No new targets, no new dependencies.

## Complexity Tracking

> **No Constitution Check violations. Complexity tracking N/A.**
