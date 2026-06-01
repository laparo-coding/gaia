# Feature Specification: Controller Design

**Feature Branch**: `007-controller-design`
**Created**: 2026-05-31
**Status**: Draft
**Input**: User request: "The app is a controller for the coach to flip through presentation slides during a course day. The slides shall be rendered on the iPad screen on the left-hand side and cover no more than 75% of the screen width. There is an HTML player in Aither to render presentation slides on a big screen in 4K. Keep this screen ratio to render the HTML files on the iPad screen. There need to be buttons for flipping through the slides forward and backward beneath the HTML player on the iPad screen. The right-hand side of the iPad screen is used to display additional text information that comes along with the slides. This text information spans from top to bottom of the right-hand side."

## Problem Statement

The coach needs a dedicated iPad controller view for running through presentation slides during a course day. The iPad must act as the control surface, not the primary presentation output. Slide content is rendered in a left-hand HTML player area that mirrors the 4K HTML presentation ratio used by the big-screen player in Aither. Additional slide notes and supporting text must be visible on the right-hand side of the iPad screen from top to bottom. The interface must provide clear forward and backward controls directly beneath the slide player.

## Goals

- Provide a coach-facing controller UI for slide navigation during a course day.
- Render slide HTML on the left side of the iPad screen while preserving the same aspect ratio used by the 4K HTML player in Aither.
- Keep the slide viewport within 75% of the iPad screen width.
- Display supporting text content for the current slide in a right-hand panel that spans the full height of the screen.
- Provide forward and backward buttons beneath the slide player for slide navigation.

## Non-Goals

- Full authoring or editing of presentation slide content.
- Replacing the 4K HTML player used for the large screen.
- Portrait mode support on iPad.
- Gesture-only navigation without visible controls.
- Keyboard, remote-control, or gesture-based slide navigation beyond the visible forward and backward buttons.

## Clarifications

### Session 2026-05-31

- Q: Where do slide HTML and supplemental notes come from for the controller? → A: API fetch from Aither for the active presentation.
- Q: How should the controller behave while slides or notes are loading or unavailable? → A: Show a loading indicator within 300 ms after fetch start; on failure, show an inline error with title, short reason, and retry action.
- Q: Should the right-hand notes panel support scrolling when notes exceed the visible height? → A: Yes, only the right-hand text panel scrolls independently.
- Q: Should the controller support additional navigation inputs beyond the visible buttons? → A: No, only the visible forward and backward buttons.
- Q: What should happen if final slide notes are not yet defined for this implementation step? → A: The controller may show a placeholder text panel until the real notes content is defined later.

## User Stories

1. As a coach, I want to quickly open the next or previous slide on the iPad so that I can guide the course confidently.
2. As a coach, I want to see the slide on the left using the same HTML ratio as the 4K display so that the presentation remains consistent.
3. As a coach, I want to see supplemental text fully on the right so that I can use notes and cues during the course.

## Requirements

### Functional Requirements

- FR-001: The app SHALL provide a controller view for iPad use in landscape mode.
- FR-002: The controller view SHALL split the screen into a left slide area and a right text area.
- FR-003: The left slide area SHALL render presentation slides as HTML content.
- FR-004: The left slide area SHALL occupy no more than 75% of the screen width.
- FR-005: The left slide area SHALL preserve the same HTML aspect ratio used by the 4K presentation player in Aither.
- FR-006: The controller view SHALL provide a forward button beneath the slide area.
- FR-007: The controller view SHALL provide a backward button beneath the slide area.
- FR-008: The right text area SHALL display supplemental text associated with the current slide and MAY temporarily show placeholder text when final notes are not yet defined.
- FR-009: The right text area SHALL span from the top to the bottom of the iPad screen.
- FR-010: The controller view SHALL keep slide and text content synchronized for the active slide.
- FR-011: The controller view SHALL load slide HTML for the active presentation from Aither via API and SHALL support supplemental text provided either by upstream notes data or a Gaia-managed placeholder.
- FR-012: The controller view SHALL show a loading indicator within 300 ms after a slide or notes fetch starts; on failure it SHALL render an inline error containing at least an error title, a short reason, and a retry action.
- FR-013: The right text area SHALL support independent vertical scrolling when supplemental text exceeds the visible panel height.
- FR-014: The controller view SHALL support slide navigation only through the visible forward and backward buttons.

### Non-Functional Requirements

- NFR-001: On iPad landscape, previous/next buttons and the right text panel SHALL be visible at initial render without page-level vertical scrolling.
- NFR-002: During previous/next navigation, the controls row SHALL not shift vertically by more than 8 px.
- NFR-003: Previous/next buttons SHALL be reachable with a single tap from the default viewport without intermediate menus.
- NFR-004: The controller SHALL preserve the 4K HTML player ratio with a maximum aspect-ratio deviation of 1% on iPad landscape.
- NFR-005: During loading and error states, the previous/next controls SHALL remain visible in the initial viewport and their vertical position SHALL not shift by more than 8 px.

## Constraints

- The controller is limited to iPad landscape mode.
- Portrait mode is explicitly out of scope.
- The iPad slide viewport must not exceed 75% of the available screen width.
- The iPad slide viewport must preserve the HTML player ratio used by the big-screen presentation output in Aither.

## Acceptance Criteria

- AC-001: On iPad landscape, the controller shows a left slide viewport and a right text panel.
- AC-002: The left slide viewport never exceeds 75% of the screen width.
- AC-003: The slide viewport preserves the same HTML ratio as the 4K player in Aither.
- AC-004: Forward and backward buttons are visible directly beneath the slide viewport.
- AC-005: The right text panel spans the full height of the screen and shows slide-related supplemental text; when placeholder text is used, the text begins with `Placeholder:`.
- AC-006: Slide navigation is available only through the visible forward and backward buttons.
