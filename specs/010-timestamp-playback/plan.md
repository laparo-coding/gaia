# Implementation Plan: Timestamp Playback

**Branch**: `010-timestamp-playback` | **Date**: 2026-07-19 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/010-timestamp-playback/spec.md`

## Execution Flow (/plan command scope)

```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 9 ("STOP - Ready for /tasks"). Phases 2-4 are executed by other commands:

- Phase 2: /tasks command executes Plan Phase 2 and creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary

Add timestamp-based chapter playback to the Gaia Controller app. The Gaia
Controller initiates playback of a seminar recording via **native AVPlayer**.
Chapter boundaries are obtained from Aither's JSON chapter manifest
(`GET /api/recording/chapters/[id]`, sourced from embedded ffmpeg metadata in
the MUX chaptered asset — Aither Spec 010, already implemented on branch
`010-chapters-in-video`). A new **"Next Chapter" button** in the player
performs a **client-side seek** to the first chapter whose `start` exceeds the
current playback position (no Aither round-trip). Regeneration is triggered
**explicitly** by the operator via `POST /api/recording/chapters/[id]`
(synchronous, Bearer auth via Spec 005). When the chapter list is unavailable
(`404 CHAPTERS_NOT_GENERATED`), the button is disabled with a hint to trigger
regeneration first.

## Technical Context

**Language/Version**: Swift 6.x (package targets), Swift 6.1 manifest
**Primary Dependencies**: SwiftPM, Foundation (`URLSession`), SwiftUI (controller
app), **AVFoundation / AVKit** (`AVPlayer` + `AVPlayerViewController` for
playback — native, no third-party MUX SDK; see research R1), existing `GaiaCore`
modules (`Authentication`, `Controller`, `Configuration`)
**Storage**: In-memory chapter list cache (short-lived, per-assetId); no
persistent storage
**Testing**: Swift Testing / XCTest per existing `GaiaCoreTests` convention;
unit, contract, and integration scenarios under `Tests/GaiaCoreTests/Playback`
**Target Platform**: iPadOS Controller app in landscape mode. iPadOS build,
simulator, and device validation are not required quality gates for this feature.
**Project Type**: swift-package with Apple-platform app target
(`GaiaControllerApp`)
**Editor Workflow**: VS Code + `swiftlang.swift-vscode` + LLDB DAP; tasks
`swift: Build Debug`, `swift: Test`, `swift: Format`, `swift: Lint`
**Performance Goals**: "Next Chapter" jump ≤ 200 ms from button press to
playback position change (NFR-001, client-side seek)
**Constraints**: Sendable-safe clients; structured errors; no secrets in source;
Bearer auth via Spec 005; explicit-trigger-only for regeneration
**Scale/Scope**: New `Playback` module in `GaiaCore` + new player view in
`GaiaControllerApp`; reuses existing `DownstreamServiceClient` and
`AitherServiceAuthenticator`

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- [x] Specs-first flow preserved: `spec.md` → `plan.md` → `tasks.md` before implementation
- [x] Tests are designed to fail before implementation begins (contract + integration tests authored first, Constitution II)
- [x] Structure uses `Package.swift`, `Sources/`, and `Tests/` (no exception needed; new `Playback/` module follows existing convention)
- [x] VS Code build, test, debug, format, and lint commands are identified (existing `swift: *` tasks)
- [x] Swift API design, concurrency, and type-safety implications documented (Sendable client structs, structured `PlaybackError`, actor-isolated player state)
- [x] Security, observability, and failure handling are covered (Bearer auth via Spec 005, structured errors, soft-fail on chapter fetch, no secrets in source)

**Result**: PASS. No violations; Complexity Tracking not required.

### Key constitutional alignment notes

- **I. Spec-First**: This plan is produced before any playback code exists;
  `research.md` captures the Aither contract decisions and the native AVPlayer
  choice (research R1).
- **II. Test-First**: Contract tests for `GET /api/recording/chapters/[id]` and
  `POST /api/recording/chapters/[id]` are authored before the client
  implementation. Player seek logic tests precede the SwiftUI view.
- **III. VS Code Toolchain**: All work builds via `swift build` from the command
  line; no Xcode-only steps. No third-party player SDK dependency.
- **IV. Concurrency**: New `PlaybackClient` is a `Sendable` struct reusing
  `DownstreamServiceClient`; player state is `@MainActor` (SwiftUI
  `ObservableObject`).
- **V. Package Boundaries**: New `Sources/GaiaCore/Playback/` module; minimal
  public surface. Player view lives in `app/controller/` (existing app target).
- **VI. Security**: Bearer token via `DownstreamServiceClient` (never in source);
  structured `PlaybackError`; no placeholder chapter data on production path.
- **Device scope**: The product targets iPadOS landscape. iPadOS build and device
   validation are not quality gates for this feature.

## Project Structure

### Documentation (this feature)

```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)

```
Package.swift                      # No new dependencies (native AVPlayer)
Sources/
└── GaiaCore/
    ├── Authentication/            # Reused: DownstreamServiceClient, AitherServiceAuthenticator
    ├── Configuration/
    │   └── LocalEnvironment.swift  # Extend: GAIA_PLAYBACK_CHAPTER_CACHE_TTL_SECONDS (existing), playback keys
    ├── Controller/                # Reused: AitherControllerClient
    └── Playback/                  # NEW module
        ├── PlaybackClient.swift        # Aither chapter manifest + regeneration client
        ├── ChapterManifest.swift       # ChapterSummary model + decoding
        ├── PlaybackError.swift         # Structured error enum
        ├── ChapterSeekLogic.swift      # Pure: next-chapter computation (position-relative)
        └── PlaybackAsset.swift         # MUX asset id + playback URL

app/
└── controller/
    ├── VideoPlayerView.swift      # NEW: AVPlayer SwiftUI wrapper (AVPlayerViewController)
    ├── VideoPlayerViewModel.swift # NEW: @MainActor player state + seek
    ├── NextChapterButton.swift    # NEW: disabled-state + hint UX
    └── ControllerRootView.swift   # Modify: add video playback surface

Tests/
├── GaiaCoreTests/
│   └── Playback/
│       ├── ChapterSeekLogicTests.swift     # Pure next-chapter computation
│       ├── PlaybackClientTests.swift       # Decoding + error mapping
│       └── ChapterManifestTests.swift      # Schema validation
│       ├── ChaptersGetContractTests.swift  # GET /api/recording/chapters/[id]
│       ├── ChaptersPostContractTests.swift # POST /api/recording/chapters/[id]
│       ├── StreamGetContractTests.swift    # GET /api/recording/stream/[id]
│       └── PlaybackFlowTests.swift         # End-to-end playback flow
```

**Structure Decision**: Standard SwiftPM layout (Constitution V). New
`Sources/GaiaCore/Playback/` module follows the existing per-feature directory
convention (`Authentication/`, `Dashboard/`, `Controller/`). Player UI lives in
the existing `app/controller/` target alongside `ControllerRootView`. All
playback tests are registered in the `GaiaCoreTests` SwiftPM target.
Playback uses native `AVPlayer`/`AVPlayerViewController` (AVFoundation/AVKit) —
no third-party MUX SDK dependency (research R1: the `mux-player-swift` package
has a macOS platform conflict that breaks `swift build`).

## Phase 0: Outline & Research

Unknowns and decisions to resolve in `research.md`:

1. ~~**MUX iOS Player SDK**~~ — **Superseded**: native `AVPlayer` used
   instead (research R1: `mux-player-swift` has a macOS platform conflict).
   No SwiftPM dependency needed.
2. **MUX asset id → playback URL** — How does Gaia obtain the MUX playback URL
   for a given `assetId`? Aither's `GET /api/recording/chapters/[id]` returns
   chapter metadata but the playback URL is served by
   `GET /api/recording/stream/[id]` (redirect to MUX CDN). Decision: Gaia calls
   the stream endpoint to resolve the URL, or Aither exposes the MUX playback
   URL in the chapter response. Record rationale + impact.
3. **Chapter list caching** — TTL and invalidation for the in-memory chapter
   list cache. Decision: short-lived (≤ 60s) per-assetId, invalidated on
   regeneration success (FR-007).
4. **Player position observation** — How to observe current playback position
   for the "Next Chapter" computation (`AVPlayer.currentTime()` periodic
   time observer / Combine). Decision + rationale.
5. **Regeneration failure UX** — How Aither error codes (`409`, `422`, `502`,
   `503`) surface in the Gaia UI. Decision: structured `PlaybackError` mapping
   with user-facing German messages; operator retry action.
6. **Aither contract reuse** — Confirm Aither's implemented Spec 010 endpoints
   (`POST/GET /api/recording/chapters/[id]`, `GET /api/recording/stream/[id]`)
   are the exact contract Gaia consumes; no Gaia-side contract changes needed.
7. **Best practices** — Swift 6 `Sendable`/`@MainActor` patterns for video
   player view models; AVPlayer integration in SwiftUI; seek-while-playing
   semantics.

**Output**: `research.md` with all decisions resolved (no NEEDS CLARIFICATION).

## Phase 1: Design & Contracts

_Prerequisites: research.md complete_

1. **`data-model.md`** — Document the new entities:
   - `ChapterSummary` (`id: Int`, `start: Double`, `end: Double`, `title: String`)
     — seconds-based, from Aither `GET /api/recording/chapters/[id]`.
   - `ChapterListResponse` (`assetId: String`, `chapters: [ChapterSummary]`).
   - `ChapterRegenerationResult` (`assetId`, `muxAssetId`, `chapterCount`).
   - `PlaybackAsset` (`assetId`, `playbackURL: URL`).
   - `PlaybackError` enum (cases: `chaptersNotGenerated`, `recordingNotFound`,
     `ffmetadataNotFound`, `recordingInProgress`, `ffmetadataInvalid`,
     `remuxFailed`, `blobStorageUnavailable`, `unauthorized`, `forbidden`,
     `networkFailure`, `invalidResponse`).
   - Validation rules: monotonic chapters, `start < end`, no overlaps.
   - State transitions: `unloaded → loadingChapters → ready → playing`;
     `ready → regenerating → ready`; `loadingChapters → chaptersNotGenerated`.
2. **`contracts/`** — Capture the Aither contracts Gaia consumes (from Aither's
   implemented Spec 010):
   - `contracts/chapters-api.md` — `GET /api/recording/chapters/[id]` (chapter
     list, `404 CHAPTERS_NOT_GENERATED`) and `POST /api/recording/chapters/[id]`
     (regeneration, synchronous, `200`/`404`/`409`/`422`/`502`/`503`).
   - `contracts/stream-api.md` — `GET /api/recording/stream/[id]` (MUX CDN
     redirect, Range support).
   - Auth: `Authorization: Bearer` via Spec 005 `DownstreamServiceClient`.
3. **Contract tests** — One failing test per endpoint:
   - `chapters-get.contract.swift` — asserts request headers (Bearer), response
     decoding (`ChapterListResponse`), `404 CHAPTERS_NOT_GENERATED` mapping.
   - `chapters-post.contract.swift` — asserts regeneration request, `200`
     decoding (`ChapterRegenerationResult`), error code matrix mapping.
   - Tests MUST fail before implementation (no client code yet).
4. **Integration scenarios** — From the spec's functional requirements:
   - (a) Load chapter list → player ready with "Next Chapter" enabled.
   - (b) Press "Next Chapter" mid-chapter → client-side seek to next `start`.
   - (c) Press "Next Chapter" in last chapter → button disabled.
   - (d) `404 CHAPTERS_NOT_GENERATED` → button disabled + hint shown.
   - (e) Explicit regeneration trigger → `200` → chapter list refreshed.
   - (f) Regeneration failure (`502`) → structured error + retry action.
   - Map to `Tests/GaiaCoreTests/Playback/PlaybackFlowTests.swift`.
5. **`quickstart.md`** — Runnable validation: set env (Aither base URL + Bearer
   token), `swift build`, run playback tests, expected outcome: chapter list
   loaded, "Next Chapter" seeks correctly, regeneration trigger works against a
   real Aither instance (or mock).
6. **Agent context update** — Run `.specify/scripts/bash/update-agent-context.sh copilot`
   to record new tech (MUX SDK, Playback module) and paths; preserve manual
   additions; update the plan reference between the SPECKIT markers in
   `.github/copilot-instructions.md`.

**Output**: `data-model.md`, `contracts/chapters-api.md`, `contracts/stream-api.md`,
failing contract/integration tests, `quickstart.md`, updated agent context.

## Phase 2: Task Planning Approach

_This section describes what the /tasks command will do - DO NOT execute during /plan_

**Task Generation Strategy**:

- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each contract → contract test task [P]
- Each entity → model creation task [P]
- Each user story → integration test task
- Implementation tasks to make tests pass

**Ordering Strategy**:

- TDD order: Tests before implementation
- Dependency order: Models before services before UI
- Mark [P] for parallel execution (independent files)

**Estimated Output**: 15-25 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation

_These phases are beyond the scope of the /plan command_

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking

_Fill ONLY if Constitution Check has violations that must be justified_

| Violation                  | Why Needed         | Simpler Alternative Rejected Because |
| -------------------------- | ------------------ | ------------------------------------ |
| [e.g., 4th project]        | [current need]     | [why 3 projects insufficient]        |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient]  |

## Progress Tracking

_This checklist is updated during execution flow_

**Phase Status**:

- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented

---

_Based on the active repository constitution - See `/.specify/memory/constitution.md`_
