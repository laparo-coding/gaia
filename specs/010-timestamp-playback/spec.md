# Spec 010: Timestamp Playback

## Status

Spec complete; `plan.md`, `research.md`, `data-model.md`, `contracts/`,
`quickstart.md`, and `tasks.md` generated. Ready for implementation.

## Overview

The Gaia Controller initiates playback of a video using **native AVPlayer**.
Chapter information is encoded into the video as **ffmpeg metadata** by Aither;
Gaia reads the chapters via Aither's **JSON manifest endpoint**
(`GET /api/recording/chapters/[id]`). A new **"Next Chapter" button** is added
to the player; pressing it jumps playback to the start of the next chapter via
a client-side seek. **Aither** is responsible for regenerating the video with
the chapter metadata on explicit request.

## Background

This feature builds on the existing playback and service-connection work:

- **Spec 008 (Dashboard)** and **Spec 009 (Real Data Connections)** establish
  the Gaia ↔ Hemera/Aither integration and the Aither slide/presentation
  trigger contract.
- **Spec 005 (Authentication)** defines the `Bearer` service credentials used
  for the Aither regeneration request.
- The video is played back via **native AVPlayer** in the Gaia Controller app.
- Chapter boundaries are embedded into the video file as **ffmpeg metadata**
  (chapter markers in the container metadata) by Aither's regeneration step.
  Gaia reads the chapters primarily from Aither's **JSON manifest endpoint**
  (`GET /api/recording/chapters/[id]`), which is sourced from the embedded
  chapters in the chaptered asset (hybrid: JSON manifest primary, embedded
  metadata as source of truth).
- **Aither** owns the video pipeline and runs the regeneration of the video with
  the metadata on request from Gaia.

## Objectives

1. Gaia Controller can initiate playback of a video via native AVPlayer.
2. The player exposes a **"Next Chapter" button** that jumps to the start of
   the next chapter encoded in the video metadata.
3. Chapter information is encoded into the video as ffmpeg metadata by Aither.
4. Aither provides an on-demand **regeneration endpoint** that (re)produces the
   video with the current chapter metadata, authenticated via the existing
   service credentials (Spec 005).

## Clarifications

### Session 2026-07-19

- Q: Does the video delivery pipeline preserve the ffmpeg container chapter metadata through its processing, or should Aither expose a side-channel chapter manifest? → A: **Hybrid (Option C).** Gaia reads chapters from the JSON manifest endpoint `GET /api/recording/chapters/[id]` as the primary source; the embedded chapters in the chaptered asset are the underlying source of truth (verified against Aither's implemented Spec 010 on branch `010-chapters-in-video`).
- Q: How should the "Next Chapter" button determine the next chapter boundary — relative to the current playback position, or only after the player has reached/paused at the current chapter's `end`? → A: **Position-relative (Option A).** The button finds the next chapter whose `start` is greater than the current playback position and seeks there. This works mid-chapter (skip ahead) and at paused boundaries, and does not force the user to wait for a chapter to finish before skipping.
- Q: Should the "Next Chapter" button trigger Aither's `POST /api/recording/playback/play` with `{ chapterId }` (server-driven seek + boundary pause), or perform a client-side seek on the AVPlayer directly (Gaia-driven, no Aither round-trip)? → A: **Client-side seek (Option B).** The button seeks the AVPlayer directly to the next chapter's `start` using the already-loaded chapter list (from `GET /api/recording/chapters/[id]`); no Aither round-trip. Aither's `chapterId`-based playback endpoint remains available for programmatic/automated chapter addressing (e.g. dashboard triggers), not for interactive button presses.
- Q: When should Gaia trigger the Aither regeneration (`POST /api/recording/chapters/[id]`) — automatically when a recording is finalized, or only on explicit user/operator action? → A: **Explicit trigger only (Option B).** Gaia triggers regeneration via an explicit operator/programmatic action (e.g. a "Regenerate chapters" control), mirroring Aither's pull-based model. No automatic trigger on recording finalization, to avoid regenerating with incomplete ffmetadata.
- Q: How should Gaia handle the case where the chapter list is not yet available (e.g. `GET /api/recording/chapters/[id]` returns `404 CHAPTERS_NOT_GENERATED`)? → A: **Disable button + show hint (Option A).** The "Next Chapter" button is disabled and the UI shows a hint prompting the operator to trigger regeneration first. The button stays disabled until regeneration succeeds and the chapter list loads. Consistent with the explicit-trigger model (Q4) and Aither's `404 CHAPTERS_NOT_GENERATED` response.

## Requirements

### Functional Requirements

- **FR-001**: The Gaia Controller MUST be able to initiate playback of a video
  using **native AVPlayer**.
- **FR-002**: The player MUST expose a **"Next Chapter" button**. Pressing the
  button MUST jump playback to the start timestamp of the **next chapter**
  relative to the current playback position — i.e. the first chapter whose
  `start` is greater than the current playback position. This MUST work both
  mid-chapter (skip ahead) and when the player is paused at a chapter boundary.
  The jump MUST be performed as a **client-side seek on the AVPlayer** using
  the already-loaded chapter list; no Aither playback round-trip is required
  for the button press.
- **FR-003**: Chapter information MUST be encoded into the video as **ffmpeg
  metadata** (chapter markers in the container metadata) by Aither's regeneration
  step. Gaia MUST read the chapter boundaries primarily from the **JSON chapter
  manifest** exposed by Aither (`GET /api/recording/chapters/[id]`), which is
  sourced from the embedded chapters in the chaptered asset (single source of
  truth = the chaptered asset). The embedded container metadata is the
  underlying source of truth; the JSON manifest is the canonical Gaia-facing
  representation.
- **FR-004**: If the current playback position is within (or past) the last
  chapter (i.e. no chapter has a `start` greater than the current position),
  the "Next Chapter" button MUST be disabled (or perform no jump).
- **FR-004a**: If the chapter list is not yet available (e.g. `GET /api/recording/chapters/[id]` returns `404 CHAPTERS_NOT_GENERATED`), the "Next Chapter" button MUST be disabled and the UI MUST show a hint prompting the operator to trigger regeneration first. The button MUST stay disabled until regeneration succeeds and the chapter list loads. Gaia MUST NOT auto-trigger regeneration in this state.
- **FR-005**: Aither MUST provide an on-demand **regeneration endpoint** that
  (re)produces the video with the current chapter metadata embedded as ffmpeg
  metadata. Gaia MUST trigger this endpoint **only via an explicit
  operator/programmatic action** (e.g. a "Regenerate chapters" control); Gaia
  MUST NOT trigger regeneration automatically on recording finalization, to
  avoid regenerating with incomplete ffmetadata (mirrors Aither's pull-based
  model).
- **FR-006**: Gaia MUST trigger the Aither regeneration via the authenticated
  service contract from Spec 005 (`Authorization: Bearer`). The trigger is
  synchronous (Aither blocks until FFmpeg remux completes) and idempotent
  (re-invocation overwrites the existing chaptered asset).
- **FR-007**: After a successful regeneration, Gaia MUST reload/refresh the
  chapter list (via `GET /api/recording/chapters/[id]`) and the playback asset
  so the newly encoded chapter metadata is reflected in the player. The
  "Next Chapter" button MUST use the refreshed chapter list for subsequent
  jumps.
- **FR-008**: When `GET /api/recording/stream/[id]` returns a non-success status
  or times out, the player MUST display a distinct "stream unavailable" state
  (not the generic `failed` state). Stream resolution accepts exactly two
  successful outcome classes:
  1. **Direct 2xx response** — a final `200`–`299` status from the server
     (or `URLSession` following internal redirects) is treated as a valid
     resolved stream URL; the client uses the final response URL for playback.
  2. **HTTP 302 redirect** — an explicit `302 Found` response with a `Location`
     header is treated as successful; the client extracts the redirect target
     URL for playback. This is the *only* permitted redirect hop; all other
     `3xx` statuses (`301`, `303`, `307`, `308`, etc.) MUST be classified as
     stream failures and produce the stream-unavailable path. Any non-`2xx`,
     non-`302` status (including `4xx`/`5xx` errors and timeouts) is likewise
     a stream failure. The UI
  MUST offer a single-tap retry button that re-requests the stream URL without
  requiring the operator to navigate away. After 3 consecutive failures, the
  retry button MUST be disabled and the error message MUST include guidance to
  check the recording status.
  The disabled-retry state MUST be reset when the operator navigates away
  from the video playback surface and back (dismissal + re-entry), or when
  a dashboard refresh (`loadDashboard`) completes, clearing the consecutive
  failure counter and re-enabling the retry button. Recovery: once the stream
  becomes available (e.g. after processing completes), the next retry attempt
  MUST succeed and transition the player to the `ready` state.

### Non-Functional Requirements

- **NFR-001**: The "Next Chapter" jump MUST be near-instantaneous from the
  user's perspective. Since the jump is a client-side seek on the AVPlayer
  using the already-loaded chapter list (no Aither round-trip), the target
  latency is **≤ 200 ms** from button press to playback position change.
  - **Measurement methodology:**
    - **T₀ (button press):** Timestamp recorded in the button action closure before invoking the seek.
    - **T₁ (seek invocation):** Timestamp recorded immediately before calling `AVPlayer.seek(to:toleranceBefore:toleranceAfter:)`.
    - **T₂ (position change observed):** Timestamp recorded in the `periodicTimeObserver` callback when `CMTimeGetSeconds(player.currentTime())` first equals the target chapter's start time (± 50 ms tolerance).
    - **Measured latency:** T₂ − T₀.
    - **Pass/fail rule:** The median of 10 consecutive jumps on a Wi-Fi-connected iPad (11-inch, 4th gen) with a cached chapter list MUST be ≤ 200 ms. A single outlier > 500 ms triggers investigation but does not fail the criterion.
- **NFR-002**: The Aither regeneration request MUST use the existing
  authenticated service-to-service contract; no interactive user session.
- **NFR-003**: Chapter metadata MUST survive standard video delivery through
  the video delivery pipeline (i.e. the embedded chapters must be readable
  via `ffprobe -show_chapters` on the playback URL after processing). This is
  verified by Aither's
  existing SC-002 (Aither-side validation gate); Gaia relies on the JSON
  manifest as primary, with embedded metadata as the underlying source of
  truth.
- **NFR-004**: Stream-load failure recovery MUST be validated by contract
  tests covering both a `503 Service Unavailable` response and a request
  timeout from the stream endpoint. Each test MUST verify the player enters
  the "stream unavailable" state and transitions back to `ready` after
  retry.

## User Scenarios & Testing

### User Story 1 — Play a Chaptered Video (Priority: P1)

As a seminar operator, I want to play a chaptered seminar recording in the
Gaia Controller so that I can present the recorded content with chapter
navigation.

**Acceptance Scenarios**:
1. **Given** a chaptered asset exists for `assetId` with at least two chapters
   whose `start` values span the playback timeline, **When** the operator
   opens the player, **Then** the chapter list loads from
   `GET /api/recording/chapters/[id]` and the "Next Chapter" button is
   enabled (because a chapter with `start > currentPosition` exists).
2. **Given** the player is playing mid-chapter, **When** the operator presses
   "Next Chapter", **Then** the player seeks to the next chapter's `start`
   (client-side, ≤ 200 ms).
3. **Given** the player is in the last chapter, **When** the operator would
   press "Next Chapter", **Then** the button is disabled.

### User Story 2 — Regenerate Chapters Explicitly (Priority: P1)

As a seminar operator, I want to trigger chapter regeneration explicitly so
that the player reflects the latest chapter metadata.

**Acceptance Scenarios**:
1. **Given** a finalized recording with a valid ffmetadata blob, **When** the
   operator presses "Regenerate chapters", **Then** Gaia calls
   `POST /api/recording/chapters/[id]` (Bearer auth), the chapter list is
   refreshed, and the player uses the new chapters.
2. **Given** regeneration fails with `502 REMUX_FAILED`, **Then** the UI shows
   "Video-Regeneration fehlgeschlagen. Erneut versuchen?" with a retry action.

### User Story 3 — Missing Chapters Handling (Priority: P1)

As a seminar operator, I want clear guidance when chapters are not yet
available so that I know to trigger regeneration.

**Acceptance Scenarios**:
1. **Given** `GET /api/recording/chapters/[id]` returns `404
   CHAPTERS_NOT_GENERATED`, **Then** the "Next Chapter" button is disabled and
   the UI shows a hint prompting regeneration. Gaia does NOT auto-trigger
   regeneration.

## Validation Gates

- `swift build` compiles without errors.
- `swift test` passes all 151 tests (including Playback contract, flow, and seek logic tests).
- `swift format lint --strict` reports no formatting issues.
- Codacy static analysis reports 0 findings on modified files.

## Open Questions

- What is the exact ffmpeg metadata format used for chapter markers (e.g.
  `-metadata`/`-chapters` via ffmetadata)? _(Resolved for Aither: FFMETADATA1
  text format via `-map_metadata 1 -codec copy`; Gaia consumes the JSON
  manifest, not the raw ffmetadata.)_
- ~~Does MUX preserve container chapter metadata through its transcoding/delivery
  pipeline, or does Aither need to provide a side-channel chapter manifest?~~
  _(Resolved 2026-07-19: Hybrid — JSON manifest primary, embedded metadata
  as source of truth.)_
- Which Aither endpoint path/payload triggers the regeneration, and is it sync
  or async (job-based with status polling/SSE)? _(Resolved for Aither:
  `POST /api/recording/chapters/[id]`, synchronous.)_
- Should the "Next Chapter" button also expose a "Previous Chapter" action?
  _(Out of scope for this feature; deferred to a future spec.)_
- How are chapter boundaries authored/updated before regeneration is triggered?
  _(Out of scope for Gaia; chapter authoring is owned by Uranos/Aither Spec 009.)_
