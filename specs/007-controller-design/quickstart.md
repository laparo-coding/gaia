# Quickstart: Controller Design

## Goal

Validate Gaia's iPad controller flow for Aither-backed slide playback and note viewing.

## Prerequisites

1. A Gaia server-side controller bridge is running with valid Aither service credentials.
2. Aither exposes an active controller manifest and slide HTML for the selected course day.
3. The local Swift toolchain can run `swift build`, and a full Xcode toolchain is available for iPad simulator or device validation.
4. The controller app or simulator is configured for iPad landscape testing.

## Validation Scenarios

### Scenario 0: iPad controller app target builds for iPad landscape

1. Ensure the app project/scheme is wired for `GaiaControllerApp`.
2. Run `scripts/ci-cd/validate-controller-ipad-build.sh`.
3. Verify the build completes successfully for an iPad simulator destination.
4. Confirm the app can be launched in landscape mode without startup layout errors.

### Scenario 1: Initial presentation load shows slide and notes

1. Start the Gaia controller bridge and the iPad controller shell.
2. Open the controller for a course with generated slides.
3. Verify the left viewport loads the active slide HTML in a 16:9 frame capped at 75% width.
4. Verify the right panel shows the notes for the same active slide or the current placeholder text when final notes are not yet defined.

### Scenario 2: Forward and backward buttons change the active slide

1. Start on slide index `n` where both previous and next slides exist.
2. Tap the forward button.
3. Verify the slide viewport changes to slide `n + 1` and the notes panel updates to the matching notes.
4. Tap the backward button and verify the controller returns to slide `n`.

### Scenario 3: Long notes scroll only in the right panel

1. Load a slide whose notes or placeholder text exceed the visible panel height.
2. Scroll inside the right-hand notes panel.
3. Verify the notes content scrolls independently while the slide viewport and navigation buttons remain fixed.

### Scenario 4: Loading and failure states stay explicit and layout-stable

1. Simulate a delayed manifest or slide fetch.
2. Verify the controller shows a spinner or skeleton without moving the navigation controls.
3. Simulate an upstream Aither failure for the active slide.
4. Verify the controller shows a clear inline error message and does not silently reuse stale content.

### Scenario 5: Navigation input is limited to the visible buttons

1. Load the controller on iPad in landscape mode.
2. Attempt swipe gestures, external keyboard arrow input, or other non-button navigation paths.
3. Verify none of these inputs changes the active slide.
4. Verify the visible previous and next buttons still work.

### Scenario 6: Placeholder notes are clearly identifiable

1. Load the controller for a presentation where final notes are not yet available.
2. Verify the right-hand panel shows placeholder text instead of an empty state.
3. Verify the placeholder text is visually identifiable as temporary content.

### Scenario 7: Bridge authentication remains server-side

1. Inspect the iPad controller client configuration and network traffic.
2. Verify the client only talks to Gaia bridge endpoints and never stores or sends Aither Bearer credentials directly.
3. Confirm the Gaia bridge performs the upstream Aither authorization on behalf of the client.

### Scenario 8: Performance profiling meets T029B targets

1. Ensure Gaia bridge and Aither upstream are reachable from the profiling host.
2. Run `scripts/ci-cd/measure-controller-performance.sh`.
3. Verify the report file `specs/007-controller-design/performance-results.md` is generated.
4. Confirm initial total (`presentation + first slide`) is `<= 2.0 s`.
5. Confirm mean `next` navigation response is `<= 150 ms`.

## Execution Log (2026-05-31)

### Scenario 0

- Status: PASS
- Command: `./scripts/ci-cd/validate-controller-ipad-build.sh`
- Result: completed with `** BUILD SUCCEEDED **` using `generic/platform=iOS Simulator`.

### Scenario 1

- Status: PARTIAL
- Evidence: GaiaCore client and controller-bridge routing now target `GET /api/slides/controller` and map slide metadata plus notes for the iPad payload.
- Gap: end-to-end runtime validation still requires the iPad controller app target and a running bridge process.

### Scenario 2

- Status: PARTIAL
- Evidence: GaiaCore client and bridge routes are wired to `POST /api/slides/controller/navigation`, and the iPad view model now consumes the navigation response including active slide metadata.
- Gap: runtime verification on iPad landscape is pending.

### Scenario 3

- Status: PARTIAL
- Evidence: UI notes panel scaffold is independently scrollable in `app/controller/SlideNotesView.swift`.
- Gap: not validated on iPad runtime shell.

### Scenario 4

- Status: PARTIAL
- Evidence: loading and error overlay scaffold exists in `app/controller/ControllerStatusOverlay.swift`.
- Gap: no end-to-end runtime check against delayed/failed upstream responses yet.

### Scenario 5

- Status: PARTIAL
- Evidence: only visible previous/next buttons are wired in `app/controller/ControllerRootView.swift`.
- Gap: gesture/keyboard rejection not yet validated on running iPad target.

### Scenario 6

- Status: PARTIAL
- Evidence: placeholder text path present in controller client/view-model and spec prefix rule.
- Gap: not yet validated with an upstream dataset where notes are absent.

### Scenario 7

- Status: PARTIAL
- Evidence: bridge client path uses server-side `DownstreamServiceClient` with Aither authorization wiring in GaiaCore.
- Gap: live network inspection not yet executed on running controller shell.

### Scenario 8

- Status: PASS (local profiling baseline)
- Command: `BASE_URL=http://127.0.0.1:8099 COURSE_ID=course-123 ITERATIONS=10 OUT_FILE=specs/007-controller-design/performance-results.md ./scripts/ci-cd/measure-controller-performance.sh`
- Result: report generated at `specs/007-controller-design/performance-results.md` with initial total `0.003 s` and mean next navigation `0.001 s`; both within target thresholds.
- Note: run executed against a local controller-bridge mock harness to provide a reproducible baseline in this repository context.
- Live Gaia process check: `GAIA_AITHER_BASE_URL=http://127.0.0.1:3001 AITHER_SYNC_TOKEN=<local-test-token> swift run GaiaAuthenticationApp --port 8080` returns `200` on `GET /api/controller/presentation?courseId=course-123`.
- Live run command: `BASE_URL=http://127.0.0.1:8080 COURSE_ID=course-123 ITERATIONS=10 OUT_FILE=specs/007-controller-design/performance-results-live.md ./scripts/ci-cd/measure-controller-performance.sh`
- Live run result: report generated at `specs/007-controller-design/performance-results-live.md` with initial total `0.006 s` and mean next navigation `0.003 s`; both within target thresholds.

## External Dependency Validation (T029A)

- Upstream route `GET /api/slides/view` exists in Aither at `src/app/api/slides/view/route.ts`.
- Upstream routes `GET /api/slides/controller` and `POST /api/slides/controller/navigation` are now available according to current integration status.
- Conclusion: external dependency readiness for T029A is now satisfied; remaining validation risk is limited to runtime availability for scenario execution and performance measurement.