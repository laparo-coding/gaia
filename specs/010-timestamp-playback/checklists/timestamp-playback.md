# Checklist: Timestamp Playback Requirements Quality

**Purpose**: Validate the quality, clarity, completeness, and consistency of the
requirements in `spec.md` (and supporting artifacts) for feature
`010-timestamp-playback`. This is a "unit test for the requirements" — it tests
whether the requirements are well-written, NOT whether the implementation works.

**Created**: 2026-07-19
**Focus**: Comprehensive (UX/Interaction + API/Integration + Error/Failure)
**Depth**: Standard (20-30 items, all quality dimensions)
**Audience/Timing**: Reviewer (PR/spec review before implementation)

---

## Requirement Completeness

- [x] CHK001 - Are requirements defined for all player lifecycle states (unloaded, loading, ready, playing, ended, chaptersNotGenerated, regenerating, failed)? [Completeness, data-model.md State Transitions] — Yes: `ended` added to T018; all states documented in data-model.md.
- [ ] CHK002 - Are requirements specified for the "Regenerate chapters" control's enabled/disabled states (e.g. disabled during active regeneration, during recording in progress)? [Completeness, Gap]
- [ ] CHK003 - Are requirements specified for what happens when the player fails to load the playback URL (stream endpoint failure)? [Completeness, Gap] — Stream-load failure UI, retry behavior, and recovery are not defined in spec.md.
  - **Proposed acceptance criteria:**
    - When `GET /api/recording/stream/[id]` returns a non-2xx status or times out, the player MUST display a distinct "stream unavailable" state (not the generic `failed` state).
    - The UI MUST offer a single-tap retry button that re-requests the stream URL without requiring the operator to navigate away.
    - After 3 consecutive failures, the retry button MUST be disabled and the error message MUST include guidance to check the recording status.
    - Recovery: once the stream becomes available (e.g. after processing completes), the next retry attempt MUST succeed and transition the player to the `ready` state.
  - **Test task:** Add a contract test that mocks a 503 response from the stream endpoint and verifies the player enters the "stream unavailable" state and recovers on retry.
- [ ] CHK004 - Are requirements specified for concurrent operations (e.g. operator presses "Next Chapter" while regeneration is in progress)? [Completeness, Gap]
- [ ] CHK005 - Are requirements defined for the initial player state when no assetId is selected yet? [Completeness, Gap]
- [ ] CHK006 - Are requirements specified for chapter list cache behavior on app foreground/background transitions? [Completeness, Gap]
- [ ] CHK007 - Are observability/logging requirements defined for playback failures and regeneration triggers? [Completeness, Constitution VI]

## Requirement Clarity

- [x] CHK008 - Is "near-instantaneous" in NFR-001 fully quantified (≤ 200 ms) and is the measurement point defined (button press → playback position change)? [Clarity, Spec §NFR-001] — Yes: ≤ 200 ms, button press → playback position change, client-side seek.
- [ ] CHK009 - Is "explicit operator/programmatic action" in FR-005 concrete enough (what exact control? button? menu item? CLI command?)? [Clarity, Spec §FR-005]
- [ ] CHK010 - Is the "hint" in FR-004a specified with concrete content, placement, and dismissal behavior? [Clarity, Spec §FR-004a]
- [ ] CHK011 - Is "refresh the playback asset" in FR-007 unambiguous (full reload vs. hot-swap vs. URL re-resolution)? [Clarity, Spec §FR-007]
- [x] CHK012 - Is the term "chapter list" vs "chapter manifest" vs "JSON manifest" used consistently across spec, data-model, and contracts? [Clarity, Terminology] — Resolved: "chapter list" used in code/UI, "JSON manifest" in spec prose, "ChapterListResponse" in data model. Consistent within each context.
- [ ] CHK013 - Are the units for chapter `start`/`end` explicitly stated in the spec (seconds), or only in data-model.md? [Clarity, Spec §FR-003]

## Requirement Consistency

- [x] CHK014 - Do the Overview, Background, and FR-003 all consistently describe the hybrid chapter-source model (JSON manifest primary, embedded metadata as source of truth)? [Consistency, Spec §Overview/Background/FR-003] — Updated: MUX references removed; model is JSON manifest from Aither API as single source of truth.
- [x] CHK015 - Is the client-side seek decision (FR-002) consistent with the regeneration trigger model (FR-005) — i.e. no Aither round-trip for seek, but Aither round-trip for regeneration? [Consistency, Spec §FR-002/FR-005] — Yes: seek is local AVPlayer seek; regeneration calls Aither POST endpoint.
- [x] CHK016 - Are the error codes in data-model.md `PlaybackError` consistent with the Aither contract error matrix in `contracts/chapters-api.md`? [Consistency, data-model.md/contracts] — Yes: both GET and POST error tables now aligned; `PlaybackClient` maps all codes.
- [x] CHK017 - Does the "disabled in last chapter" requirement (FR-004) align with the position-relative seek logic in data-model.md (`nextChapter` returns nil)? [Consistency, Spec §FR-004/data-model.md] — Yes: `nextChapter` returns nil when no chapter has a start > current position; quickstart row 3a documents single-chapter disabled state.
- [ ] CHK018 - Are the User Stories' acceptance scenarios consistent with the FR requirements (e.g. US1 scenario 2 ≤ 200 ms matches NFR-001)? [Consistency, Spec §User Stories/NFR-001]

## Acceptance Criteria Quality

- [ ] CHK019 - Can the "Next Chapter" jump latency (≤ 200 ms, NFR-001) be objectively measured in a test? [Measurability, Spec §NFR-001]
- [ ] CHK020 - Are the User Story acceptance scenarios measurable (given/when/then with concrete outcomes)? [Acceptance Criteria, Spec §User Stories]
- [ ] CHK021 - Is "idempotent regeneration" (FR-006) defined with a measurable criterion (same response shape, same chapter count)? [Measurability, Spec §FR-006]
- [ ] CHK022 - Can the "hint is shown" requirement (FR-004a) be objectively verified (what element, what text, what visibility rule)? [Measurability, Spec §FR-004a]

## Scenario Coverage

- [ ] CHK023 - Are requirements defined for the zero-chapter scenario (regeneration produces a single chapter spanning the whole video — is that valid for Gaia)? [Coverage, Edge Case]
- [x] CHK024 - Are requirements specified for the single-chapter scenario (only one timestamp ingested — "Next Chapter" always disabled)? [Coverage, Edge Case] — Yes: quickstart row 3a documents this; `nextChapter` returns nil when no subsequent chapter exists.
- [ ] CHK025 - Are requirements defined for network failure during chapter list fetch (offline / timeout)? [Coverage, Exception Flow, Gap]
- [x] CHK026 - Are requirements specified for the player reaching the end of the video (not just end of a chapter)? [Coverage] — Yes: `ended` state added to T018; `VideoPlayerViewModel` observes AVPlayer end-of-playback.
- [ ] CHK027 - Are requirements defined for chapter list fetch when the Bearer token is expired (401 → refresh once → retry)? [Coverage, Spec §FR-006/Spec 005]
- [ ] CHK028 - Are requirements specified for regeneration while the player is actively playing (pause? continue? reload asset?)? [Coverage, Gap]

## Edge Case Coverage

- [ ] CHK029 - Are requirements defined for when the chapter list and the actual video duration diverge (last chapter end ≠ video duration)? [Edge Case, Gap]
- [ ] CHK030 - Are requirements specified for malformed chapter data from Aither (e.g. non-monotonic ids, overlapping chapters)? [Edge Case, data-model.md validation rules]
- [ ] CHK031 - Is the behavior defined when the stream endpoint returns a raw (non-chaptered) asset instead of a chaptered one? [Edge Case, contracts/stream-api.md fallback]

## Non-Functional Requirements

- [ ] CHK032 - Are performance requirements defined for chapter list fetch latency (not just the seek jump)? [NFR, Gap]
- [ ] CHK033 - Are accessibility requirements specified for the "Next Chapter" button and "Regenerate chapters" control (VoiceOver labels, keyboard navigation)? [NFR, Gap, Constitution device scope]
- [ ] CHK034 - Are security requirements specified for the Bearer token storage and refresh lifecycle on the Gaia side? [NFR, Spec §FR-006/Spec 005]
- [ ] CHK035 - Is the iPad landscape orientation requirement (Constitution device scope) explicitly referenced for the player UI? [NFR, Constitution]

## Dependencies & Assumptions

- [ ] CHK036 - Is the dependency on Aither's Spec 010 being implemented and deployed documented as an assumption? [Dependency, research.md R6]
- [x] CHK037 - Is the assumption that embedded chapter metadata is preserved documented and validated (NFR-001 references Aither SC-002)? [Assumption, Spec §NFR-003] — Updated: MUX reference removed; NFR-003 clarified as Aither-side validation gate.
- [x] CHK038 - Is the dependency on the native AVPlayer availability (iOS/iPadOS version compatibility) documented? [Dependency, research.md R1] — Updated: MUX SDK dependency removed; native AVPlayer used (no external SDK dependency).
- [ ] CHK039 - Is the assumption that `GAIA_AITHER_BASE_URL` is already configured (from Spec 009) documented? [Assumption, contracts/chapters-api.md]

## Ambiguities & Conflicts

- [ ] CHK040 - Does the spec define whether the player auto-plays on load or waits for an explicit play action? [Ambiguity, Gap]
- [ ] CHK041 - Is it clear whether "Regenerate chapters" is available during playback or only when paused/stopped? [Ambiguity, Spec §FR-005]
- [ ] CHK042 - Does the spec resolve whether the chapter list is re-fetched on every player open or only on explicit refresh? [Ambiguity, Spec §FR-007/Gap]
