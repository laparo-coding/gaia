# Quickstart: Validate Timestamp Playback

Validation guide proving the Gaia Controller can play a chaptered video, jump
between chapters via the "Next Chapter" button, and trigger regeneration. See
[contracts](./contracts/chapters-api.md) and
[data-model](./data-model.md) for details.

## Prerequisites

- Swift toolchain (see repo) and VS Code with `swiftlang.swift-vscode`.
- A reachable Aither instance (branch `010-chapters-in-video`) with at least one
  finalized recording and a valid ffmetadata JSON blob, OR the Aither mock for
  local dev.
- Service credentials available via environment (never committed).
- MUX account with a chaptered asset uploaded (Aither's regeneration step
  produces this).

## Setup

Create `.env.local` at the repository root (gitignored):

```
GAIA_AITHER_BASE_URL=http://localhost:3600
GAIA_AITHER_BEARER_TOKEN=<your-aither-service-token>
# Optional:
# GAIA_PLAYBACK_CHAPTER_CACHE_TTL_SECONDS=60
```

## Build & test

```
swift build
swift test --filter Playback
```

(Or use the VS Code tasks `swift: Build Debug` and `swift: Test`.)

## Platform scope

Gaia is an iPadOS landscape app. An iPadOS build, simulator run, or device check
is not required for Spec 010.

## Validation scenarios

| # | Action                                             | Expected outcome                                                            |
| - | -------------------------------------------------- | --------------------------------------------------------------------------- |
| 1 | Load player for a recording with chapters          | Chapter list loaded from `GET /api/recording/chapters/[id]`; "Next Chapter" button enabled |
| 2 | Press "Next Chapter" mid-chapter                   | Player seeks to the next chapter's `start` (client-side, ≤ 200 ms)          |
| 3 | Press "Next Chapter" in the last chapter           | Button is disabled (FR-004)                                                 |
| 3a | Load player for a recording with a single chapter | "Next Chapter" button is disabled (only one chapter, no next to seek to) |
| 4 | Load player for a recording without chapters       | `404 CHAPTERS_NOT_GENERATED` → button disabled + hint "Bitte zuerst regenerieren" (FR-004a) |
| 5 | Press "Regenerate chapters" (explicit trigger)     | `POST /api/recording/chapters/[id]` → `200` → chapter list refreshed (FR-005, FR-007) |
| 6 | Regeneration fails (`502 REMUX_FAILED`)            | Error overlay "Video-Regeneration fehlgeschlagen. Erneut versuchen?" + retry action |
| 7 | Regeneration while recording active (`409`)        | Error "Aufnahme läuft noch. Regeneration später erneut versuchen."          |
| 8 | Unset `GAIA_AITHER_BASE_URL`                       | Explicit failure (no playback)                                              |

## Performance check

- "Next Chapter" jump completes within ≤ 200 ms from button press to playback
  position change (NFR-001, client-side seek, no Aither round-trip).

## Success criteria

- Chapter list loads from Aither and drives the "Next Chapter" button.
- Client-side seek is near-instantaneous (≤ 200 ms).
- Button disabled correctly in the last chapter and when chapters are not
  generated.
- Explicit regeneration trigger works and refreshes the chapter list.
- All error states show structured German messages with retry where applicable.
