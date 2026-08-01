# API Contract: Aither Chapters Endpoints (Gaia Consumer)

**Spec Reference**: [spec.md](../spec.md)
**Research Reference**: [research.md](../research.md)
**Source of Truth**: Aither Spec 010 (`010-chapters-in-video`, implemented on
branch `010-chapters-in-video`).

Gaia is a **pure consumer** of these endpoints. No Gaia-side contract changes.

---

## Authentication (all requests)

| Header                          | Source                                  |
| ------------------------------- | --------------------------------------- |
| `Authorization: Bearer <token>` | Env/secrets (Spec 005 FR-008b), `GAIA_AITHER_BEARER_TOKEN` |

On `401`/`WWW-Authenticate`: refresh the credential once and retry once
(Spec 005 FR-012, via `DownstreamServiceClient`).

Base URL: `GAIA_AITHER_BASE_URL` (existing, Spec 009).

---

## Endpoint 1: GET /api/recording/chapters/{id}

Retrieve the chapter list for a chaptered video. Primary source of chapter
boundaries for Gaia (FR-003).

### Request

```
GET {GAIA_AITHER_BASE_URL}/api/recording/chapters/{assetId}
Authorization: Bearer <token>
```

**Path Parameters**:
- `assetId` (string, required) — Recording session id (e.g.,
  `rec_2026-07-13T10-30-00Z`).

### Response 200

```json
{
  "assetId": "rec_2026-07-13T10-30-00Z",
  "chapters": [
    { "id": 0, "start": 5.0, "end": 20.0, "title": "Chapter 1" },
    { "id": 1, "start": 20.0, "end": 45.0, "title": "Chapter 2" }
  ]
}
```

- `start`/`end` in **seconds** (converted from ffmetadata microseconds by Aither).
- Sourced from embedded chapters in the MUX chaptered asset (single source of
  truth).

### Response 404 — `CHAPTERS_NOT_GENERATED`

```json
{ "success": false, "error": { "code": "CHAPTERS_NOT_GENERATED", "message": "..." } }
```

Gaia maps this to `PlaybackError.chaptersNotGenerated` → "Next Chapter" button
disabled + hint to trigger regeneration (FR-004a).

### Response 404 — `RECORDING_NOT_FOUND`

```json
{ "success": false, "error": { "code": "RECORDING_NOT_FOUND", "message": "..." } }
```

### Error Responses (GET)

| HTTP | Code                       | Gaia `PlaybackError`         |
| ---- | -------------------------- | ---------------------------- |
| 401  | `UNAUTHORIZED`             | `unauthorized`               |
| 403  | `FORBIDDEN`                | `forbidden`                  |
| 404  | `CHAPTERS_NOT_GENERATED`   | `chaptersNotGenerated`       |
| 404  | `RECORDING_NOT_FOUND`      | `recordingNotFound`          |

All error responses follow the canonical Aither error envelope:
```json
{ "success": false, "error": { "code": "...", "message": "..." } }
```

---

## Endpoint 2: POST /api/recording/chapters/{id}

Regenerate the chaptered video with embedded ffmpeg metadata. Triggered
**explicitly** by the operator (FR-005). Synchronous (blocks until FFmpeg remux
completes).

### Request

```
POST {GAIA_AITHER_BASE_URL}/api/recording/chapters/{assetId}
Authorization: Bearer <token>
Content-Type: application/json

{}
```

**Path Parameters**:
- `assetId` (string, required) — Recording session id.

**Body**: Empty (`{}`). All input is derived from the path parameter and stored
artifacts.

### Response 200

```json
{
  "assetId": "rec_2026-07-13T10-30-00Z",
  "muxAssetId": "mux_chapters_rec_2026-07-13T10-30-00Z",
  "chapterCount": 5
}
```

- `chapterCount` MUST equal the ffmetadata JSON `chapters[]` length.
- Idempotent: re-invocation overwrites the existing MUX chaptered asset.

### Error Responses

| HTTP | Code                       | Gaia `PlaybackError`         |
| ---- | -------------------------- | ---------------------------- |
| 400  | `INVALID_REQUEST`          | `invalidResponse`            |
| 401  | `UNAUTHORIZED`             | `unauthorized`               |
| 403  | `FORBIDDEN`                | `forbidden`                  |
| 404  | `RECORDING_NOT_FOUND`      | `recordingNotFound`          |
| 404  | `FFMETADATA_NOT_FOUND`     | `ffmetadataNotFound`         |
| 409  | `RECORDING_IN_PROGRESS`    | `recordingInProgress`        |
| 422  | `FFMETADATA_INVALID`       | `ffmetadataInvalid`          |
| 502  | `REMUX_FAILED`             | `remuxFailed`                |
| 503  | `BLOB_STORAGE_UNAVAILABLE` | `blobStorageUnavailable`     |
| 500  | `INTERNAL_ERROR`           | `invalidResponse`            |

All error responses follow the canonical Aither error envelope:
```json
{ "success": false, "error": { "code": "...", "message": "..." } }
```

---

## Endpoint 3: GET /api/recording/stream/{id}

Resolve the MUX CDN playback URL for the chaptered video (or raw video as
fallback). Used to load the player. Full contract in
[`stream-api.md`](./stream-api.md).

### Request

```
GET {GAIA_AITHER_BASE_URL}/api/recording/stream/{assetId}
Authorization: Bearer <token>
```

### Response 302

Redirect to the MUX CDN URL for the chaptered asset (or raw asset if no
chaptered variant exists). Gaia follows the redirect to obtain the `URL`.

### Fallback

If no chaptered MUX asset exists, serves the raw MUX asset (existing Spec 004
behavior).
