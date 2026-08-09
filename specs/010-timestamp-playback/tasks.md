# Tasks: Timestamp Playback

**Input**: Design documents from `/specs/010-timestamp-playback/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)

```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Phase 3.1: Setup

- [x] T001 ~~Add `mux-avplayer` SwiftPM dependency~~ — **Superseded**: native `AVPlayer` used instead (research R1: `mux-player-swift` has a macOS platform conflict). No Package.swift dependency change needed.
- [x] T002 Create `Sources/GaiaCore/Playback/` module directory and `Tests/GaiaCoreTests/Playback/` test directory
- [x] T003 [P] Extend `Sources/GaiaCore/Configuration/LocalEnvironment.swift` with `GAIA_PLAYBACK_CHAPTER_CACHE_TTL_SECONDS` (default 60, research R3)
- [x] T004 [P] Create `Tests/GaiaCoreTests/Playback/` directory

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

- [x] T005 [P] Contract test `Tests/GaiaCoreTests/Playback/ChaptersGetContractTests.swift`: assert `GET /api/recording/chapters/[id]` request headers (Bearer), `ChapterListResponse` decoding, `404 CHAPTERS_NOT_GENERATED` → `PlaybackError.chaptersNotGenerated` mapping
- [x] T006 [P] Contract test `Tests/GaiaCoreTests/Playback/ChaptersPostContractTests.swift`: assert `POST /api/recording/chapters/[id]` regeneration request, `ChapterRegenerationResult` decoding, error code matrix (`409`/`422`/`502`/`503`) → `PlaybackError` mapping
- [x] T007 [P] Contract test `Tests/GaiaCoreTests/Playback/StreamGetContractTests.swift`: assert `GET /api/recording/stream/[id]` returns 302 redirect to MUX CDN URL, Range support
- [x] T008 [P] Unit test `Tests/GaiaCoreTests/Playback/ChapterSeekLogicTests.swift`: pure `nextChapter(chapters, currentPosition)` — mid-chapter skip, at-boundary skip, last-chapter returns nil, empty chapters returns nil
- [x] T009 [P] Unit test `Tests/GaiaCoreTests/Playback/ChapterManifestTests.swift`: `ChapterSummary` decoding + validation (monotonic, `start < end`, no overlaps)
- [x] T010 [P] Unit test `Tests/GaiaCoreTests/Playback/PlaybackClientTests.swift`: `PlaybackClient` chapter list fetch with cache, regeneration trigger, error mapping, cache invalidation on regeneration success
- [x] T011 [P] Integration test `Tests/GaiaCoreTests/Playback/PlaybackFlowTests.swift`: end-to-end load chapters → player ready → next chapter seek → last chapter disabled; `404` → button disabled + hint; regeneration → refresh

## Phase 3.3: Core Implementation (ONLY after tests are failing)

- [x] T012 [P] `Sources/GaiaCore/Playback/PlaybackError.swift`: structured error enum with all cases from data-model.md + German UI messages (research R5)
- [x] T013 [P] `Sources/GaiaCore/Playback/ChapterManifest.swift`: `ChapterSummary`, `ChapterListResponse`, `ChapterRegenerationResult` models with `Decodable` + validation rules
- [x] T014 [P] `Sources/GaiaCore/Playback/PlaybackAsset.swift`: `PlaybackAsset` (assetId + playbackURL)
- [x] T015 `Sources/GaiaCore/Playback/ChapterSeekLogic.swift`: pure `nextChapter(chapters:currentPosition:)` function (FR-002, FR-004)
- [x] T016 `Sources/GaiaCore/Playback/PlaybackClient.swift`: `Sendable` struct reusing `DownstreamServiceClient` — `fetchChapters(assetId:)`, `regenerate(assetId:)`, `resolvePlaybackURL(assetId:)`, in-memory cache (TTL ≤ 60s, invalidate on regeneration, research R3)
- [x] T017 `Sources/GaiaCore/Playback/PlaybackClient.swift`: error mapping from Aither error envelope to `PlaybackError` (all codes from contracts/chapters-api.md)

## Phase 3.4: Integration (Player UI)

- [x] T018 `app/controller/VideoPlayerViewModel.swift`: `@MainActor final class ObservableObject` — player state (`unloaded`/`loadingChapters`/`ready`/`playing`/`ended`/`chaptersNotGenerated`/`regenerating`/`failed`/`streamUnavailable`), current position observation via periodic time observer (research R4), `nextChapter()` seek action, consecutive failure counter with reset on navigation-away or dashboard refresh (FR-008)
- [x] T019 `app/controller/VideoPlayerView.swift`: SwiftUI AVPlayer wrapper — load `PlaybackAsset.playbackURL`, render player, observe position, expose seek
- [x] T020 `app/controller/NextChapterButton.swift`: "Next Chapter" button — enabled state from `ChapterSeekLogic.nextChapter(...)` (FR-004), disabled + hint when `chaptersNotGenerated` (FR-004a), client-side seek on press (FR-002, ≤ 200 ms NFR-001)
- [x] T021 `app/controller/ControllerRootView.swift`: add video playback surface + "Regenerate chapters" control (explicit trigger, FR-005) + failure overlay with retry (research R5)
- [x] T022 Wire `PlaybackClient` into `VideoPlayerViewModel` with `DownstreamServiceClient` + `AitherServiceAuthenticator` (Spec 005 Bearer auth, FR-006)

## Phase 3.5: Polish

- [x] T023 [P] Add regression tests for edge cases: single chapter, empty chapter list rejection, regeneration idempotency, concurrent chapter fetch + regeneration
- [x] T024 Verify NFR-001: "Next Chapter" jump ≤ 200 ms (client-side seek, no Aither round-trip) via playback performance test
- [x] T025 [P] Update `README.md` and feature docs with playback module description
- [x] T026 [P] Update `.github/copilot-instructions.md` recent changes (keep last 3) with 010-timestamp-playback
- [x] T027 Run `swift test` and `swift format lint --strict` before review; fix any failures
- [x] T028 ~~Validate all quickstart.md scenarios (8 validation scenarios) on iPad landscape (Constitution device scope)~~ — Superseded: Gaia targets iPadOS landscape, but iPadOS build and device validation are not quality gates for Spec 010.
- [ ] T029 `Tests/GaiaCoreTests/Playback/StreamFailureContractTests.swift`: contract test mocking `503 Service Unavailable` from `GET /api/recording/stream/[id]`, verifying player enters `streamUnavailable` state, retry recovers to `ready` (FR-008, NFR-004)
- [ ] T030 `Tests/GaiaCoreTests/Playback/StreamFailureContractTests.swift`: contract test mocking request timeout from `GET /api/recording/stream/[id]`, verifying player enters `streamUnavailable` state, retry recovers to `ready` (FR-008, NFR-004)
- [ ] T031 `Tests/GaiaCoreTests/Playback/StreamFailureContractTests.swift`: unit test verifying disabled-retry reset — after 3 failures the retry button is disabled; on navigation-away + re-entry or dashboard refresh the counter resets and retry is re-enabled (FR-008)

## Dependencies

- T002 blocks T012-T017 (module directory)
- T003 blocks T016 (cache TTL config)
- Tests (T005-T011) before implementation (T012-T017)
- T013 blocks T016 (models needed by client)
- T012 blocks T016, T017 (error type needed)
- T015 blocks T020 (seek logic needed by button)
- T016 blocks T018, T022 (client needed by view model)
- T018 blocks T019, T020 (view model needed by views)
- T019, T020 block T021 (views needed by root view)
- T022 blocks T021 (wiring needed)
- T018 blocks T029, T030, T031 (streamUnavailable state needed by tests)
- Implementation (T012-T022) before polish (T023-T028)
- T029, T030, T031 after T018 (state model must include streamUnavailable)

## Parallel Example

```
# Launch T005-T011 together (all tests, different files):
Task: "Contract test chapters-get in Tests/GaiaCoreTests/Playback/"
Task: "Contract test chapters-post in Tests/GaiaCoreTests/Playback/"
Task: "Contract test stream-get in Tests/GaiaCoreTests/Playback/"
Task: "Unit test ChapterSeekLogic in Tests/GaiaCoreTests/Playback/"
Task: "Unit test ChapterManifest in Tests/GaiaCoreTests/Playback/"
Task: "Unit test PlaybackClient in Tests/GaiaCoreTests/Playback/"
Task: "Integration test PlaybackFlow in Tests/GaiaCoreTests/Playback/"

# Launch T012-T014 together (independent model files):
Task: "PlaybackError in Sources/GaiaCore/Playback/"
Task: "ChapterManifest in Sources/GaiaCore/Playback/"
Task: "PlaybackAsset in Sources/GaiaCore/Playback/"
```

## Notes

- [P] tasks = different files, no dependencies
- Verify tests fail before implementing (Constitution II)
- Commit after each task
- Avoid: vague tasks, same file conflicts
- German informal "Du" for user-facing messages (Hemera convention)

## Task Generation Rules

_Applied during main() execution_

1. **From Contracts**:
   - Each contract file → contract test task [P]
   - Each endpoint → implementation task
2. **From Data Model**:
   - Each entity → model creation task [P]
3. **From User Stories**:
   - Each story → integration test scenario
4. **From Research**:
   - Each decision → setup or implementation constraint

## Coverage Matrix

| Requirement | Task IDs | Notes |
|-------------|----------|-------|
| FR-001 (native AVPlayer playback) | T019, T022 | Player view + wiring |
| FR-002 (Next Chapter button + client-side seek) | T015, T020 | Pure seek logic + button |
| FR-003 (chapters from JSON manifest) | T013, T016 | Model + client fetch |
| FR-004 (disabled in last chapter) | T015, T020 | Seek logic returns nil → disabled |
| FR-004a (disabled + hint when no chapters) | T018, T020, T021 | State + button + hint UX |
| FR-005 (explicit regeneration trigger) | T016, T021 | Client + control |
| FR-006 (Bearer auth) | T022 | Via DownstreamServiceClient |
| FR-007 (refresh after regeneration) | T016, T018 | Cache invalidation + state |
| FR-008 (stream unavailable state + retry) | T018, T029, T030, T031 | State + retry + reset |
| NFR-001 (≤ 200 ms jump) | T020, T024 | Client-side seek + perf test |
| NFR-002 (service-to-service auth) | T022 | No interactive session |
| NFR-003 (metadata survives delivery) | T016, Aither SC-002 | Verified via Aither SC-002 |
| NFR-004 (503 + timeout recovery tests) | T029, T030 | Contract tests |
