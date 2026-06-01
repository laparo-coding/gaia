# Contract: Controller Bridge and Aither Integration

## Purpose

Define the contract between the Gaia iPad controller client, the Gaia server-side controller bridge, and the upstream Aither slide services.

Note: Final slide-note content is deferred to a later step. Until then, Gaia may populate the supplemental text field with a placeholder string.

## 1. Gaia Bridge -> iPad Controller Client

### GET `/api/controller/presentation?courseId={courseId}`

- Purpose: Load the active controller manifest for a course day.
- Authentication: Gaia-managed controller session or equivalent trusted app session. Aither service credentials never reach the iPad client.
- Success Response: `200 OK`

```json
{
  "courseId": "course-123",
  "presentationId": "presentation-2026-05-31",
  "title": "Course Day Slides",
  "aspectRatio": "16:9",
  "activeSlideIndex": 0,
  "slideCount": 12,
  "lastUpdated": "2026-05-31T08:30:00Z",
  "slides": [
    {
      "index": 0,
      "fileName": "001_intro.html",
      "htmlURL": "/api/controller/slides/001_intro.html?courseId=course-123",
      "notes": "Notes placeholder",
      "notesSource": "placeholder"
    }
  ]
}
```

- Error Responses:
  - `404 Not Found` when no active presentation is available for the course
  - `409 Conflict` when Aither reports that slide generation is incomplete or unavailable
  - `502 Bad Gateway` when the Gaia bridge cannot fetch manifest data from Aither

### POST `/api/controller/navigation`

- Purpose: Advance or reverse the active slide via button-only navigation.
- Request Body:

```json
{
  "presentationId": "presentation-2026-05-31",
  "command": "next",
  "fromIndex": 0,
  "requestId": "nav-0001"
}
```

- Success Response: `200 OK`

```json
{
  "activeSlideIndex": 1,
  "slide": {
    "index": 1,
    "fileName": "002_agenda.html",
    "htmlURL": "/api/controller/slides/002_agenda.html?courseId=course-123",
    "notes": "Notes placeholder",
    "notesSource": "placeholder"
  }
}
```

- Error Responses:
  - `400 Bad Request` for invalid command or out-of-range index
  - `409 Conflict` when the bridge and client are out of sync on the current slide
  - `502 Bad Gateway` when Aither rejects the navigation command

### GET `/api/controller/slides/{fileName}?courseId={courseId}`

- Purpose: Return the HTML payload for the requested slide.
- Success Response: `200 OK` with `Content-Type: text/html; charset=utf-8` and `Cache-Control: no-store`
- Error Responses:
  - `400 Bad Request` for invalid course or file parameters
  - `404 Not Found` when the slide file does not exist upstream
  - `502 Bad Gateway` when the bridge cannot retrieve HTML from Aither

## 2. Gaia Bridge -> Aither Upstream Contract

Status: External dependency. Upstream endpoint implementation in Aither is out of scope for this Gaia feature and must be available before Gaia integration is marked complete.

### GET `/api/slides/controller?courseId={courseId}`

- Purpose: Return the ordered slide manifest and active slide index for the current presentation. Supplemental text may be provided by Aither later, but Gaia may supply placeholder text until that upstream field exists.
- Authentication: Gaia uses server-side Aither Bearer service authorization.
- Required Response Fields:
  - `courseId`
  - `presentationId`
  - `title`
  - `aspectRatio` (`16:9`)
  - `activeSlideIndex`
  - `lastUpdated`
  - `slides[]` containing `index` and `fileName`
  - optional upstream notes data when available

### POST `/api/slides/controller/navigation`

- Purpose: Update the active slide inside Aither's presentation controller state.
- Request Body Fields:
  - `presentationId`
  - `command` (`previous` or `next`)
  - `fromIndex`
  - `requestId`
- Success Response Fields:
  - `activeSlideIndex`
  - `fileName`
  - optional upstream notes data when available

### GET `/api/slides/view?courseId={courseId}&file={fileName}`

- Purpose: Return the raw HTML for a generated slide.
- Notes:
  - This route already exists in Aither and returns HTML with `Cache-Control: no-store`.
  - Gaia bridge proxies this response rather than exposing Aither credentials to the client.

## 3. Contract Invariants

- The authoritative slide aspect ratio is always `16:9`.
- Slide ordering must be deterministic and stable across repeated manifest fetches for the same presentation version.
- Supplemental text is controller-only metadata and must not be inferred by parsing slide HTML. Until final notes are defined, Gaia may emit explicit placeholder text.
- Navigation is limited to `previous` and `next`; no jump, gesture, keyboard, or remote command surface is part of this contract.
- Upstream failures must be translated into clear bridge-level errors without leaking Aither credentials or internal filesystem details.