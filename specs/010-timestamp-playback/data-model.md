# Phase 1 Data Model: Timestamp Playback

**Spec Reference**: [spec.md](./spec.md)
**Research Reference**: [research.md](./research.md)

---

## Entities

### ChapterSummary

A single chapter boundary sourced from Aither's
`GET /api/recording/chapters/[id]` (seconds-based).

| Field | Type   | Notes                                          |
| ----- | ------ | ---------------------------------------------- |
| id    | Int    | Chapter index (0-based), monotonic              |
| start | Double | Start offset in **seconds** (≥ 0)              |
| end   | Double | End offset in **seconds** (> start)            |
| title | String | Chapter title (may be empty)                   |

**Validation rules**:
- `start < end` for all chapters.
- Chapters MUST NOT overlap: `chapters[i].end ≤ chapters[i+1].start`.
- `id` MUST be monotonic: `chapters[i].id < chapters[i+1].id`.
- Final chapter's `end` SHOULD equal the video duration.

**Decoding**: From Aither JSON `{ "id": 0, "start": 5.0, "end": 20.0, "title": "..." }`.

---

### ChapterListResponse

Response from `GET /api/recording/chapters/[id]`.

| Field    | Type                | Notes                          |
| -------- | ------------------- | ------------------------------ |
| assetId  | String              | Recording session id (echoed)  |
| chapters | [ChapterSummary]    | Ordered list, ≥ 1 element      |

**Validation rules**:
- `chapters` MUST contain at least one element.
- All `ChapterSummary` validation rules apply to the list.

---

### ChapterRegenerationResult

Response from `POST /api/recording/chapters/[id]` (success).

| Field        | Type   | Notes                                          |
| ------------ | ------ | ---------------------------------------------- |
| assetId      | String | Recording session id (echoed)                  |
| muxAssetId   | String | MUX asset id of the chaptered video            |
| chapterCount | Int    | Number of embedded chapters (≥ 1)              |

**Validation rules**:
- `chapterCount` MUST be > 0.
- `muxAssetId` MUST be non-empty.

---

### PlaybackAsset

Resolved playback target for the native AVPlayer.

| Field       | Type | Notes                                              |
| ----------- | ---- | -------------------------------------------------- |
| assetId     | String | Recording session id                             |
| playbackURL | URL   | MUX CDN URL (from `GET /api/recording/stream/[id]`) |

---

### PlaybackError

Structured error enum for all playback failures.

| Case                       | Source (Aither code)              | HTTP | German UI message |
| -------------------------- | --------------------------------- | ---- | ----------------- |
| `chaptersNotGenerated`     | `CHAPTERS_NOT_GENERATED`          | 404  | "Kapitel noch nicht generiert. Bitte zuerst regenerieren." |
| `recordingNotFound`        | `RECORDING_NOT_FOUND`             | 404  | "Aufnahme nicht gefunden." |
| `ffmetadataNotFound`       | `FFMETADATA_NOT_FOUND`            | 404  | "Kapitel-Metadaten nicht gefunden." |
| `chapterNotFound`          | `CHAPTER_NOT_FOUND`               | 404  | "Kapitel nicht gefunden." |
| `recordingInProgress`      | `RECORDING_IN_PROGRESS`           | 409  | "Aufnahme läuft noch. Regeneration später erneut versuchen." |
| `ffmetadataInvalid`        | `FFMETADATA_INVALID`              | 422  | "Kapitel-Metadaten ungültig." |
| `remuxFailed`              | `REMUX_FAILED`                    | 502  | "Video-Regeneration fehlgeschlagen. Erneut versuchen?" |
| `blobStorageUnavailable`   | `BLOB_STORAGE_UNAVAILABLE`        | 503  | "Speicher vorübergehend nicht verfügbar. Erneut versuchen?" |
| `unauthorized`             | `UNAUTHORIZED`                    | 401  | "Nicht autorisiert." |
| `forbidden`                | `FORBIDDEN`                       | 403  | "Keine Berechtigung für diese Aktion." |
| `networkFailure`           | (transport)                       | —    | "Netzwerkfehler. Erneut versuchen?" |
| `invalidResponse`          | (decoding)                        | —    | "Ungültige Antwort vom Server." |

---

## State Transitions

```
unloaded ──loadChapters──→ loadingChapters
loadingChapters ──success──→ ready
loadingChapters ──404 CHAPTERS_NOT_GENERATED──→ chaptersNotGenerated
loadingChapters ──error──→ failed

ready ──play──→ playing
playing ──nextChapter──→ playing (seek to next start)
playing ──lastChapter/end──→ ended

ready/playing ──regenerate──→ regenerating
regenerating ──success──→ ready (refresh chapters)
regenerating ──error──→ failed (with retry)
```

---

## Aither Response → Entity Mapping

| Aither response field | Maps to                  |
| --------------------- | ------------------------ |
| `assetId`             | `ChapterListResponse.assetId` / `ChapterRegenerationResult.assetId` |
| `chapters[].id`       | `ChapterSummary.id`      |
| `chapters[].start`    | `ChapterSummary.start` (seconds) |
| `chapters[].end`      | `ChapterSummary.end` (seconds)   |
| `chapters[].title`    | `ChapterSummary.title`   |
| `muxAssetId`          | `ChapterRegenerationResult.muxAssetId` |
| `chapterCount`        | `ChapterRegenerationResult.chapterCount` |
| `error.code`          | `PlaybackError` case     |

---

## Chapter Seek Logic (pure function)

```
nextChapter(chapters: [ChapterSummary], currentPosition: Double) -> ChapterSummary?
  = chapters.first(where: { $0.start > currentPosition })
```

- Returns `nil` when current position is in/past the last chapter → button
  disabled (FR-004).
- Works mid-chapter and at paused boundaries (FR-002).
- Pure function — fully testable without UI or player.
