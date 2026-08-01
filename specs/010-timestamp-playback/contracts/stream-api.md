# API Contract: Aither Stream Endpoint (Gaia Consumer)

**Spec Reference**: [spec.md](../spec.md)
**Source of Truth**: Aither Spec 010 FR-017.

---

## GET /api/recording/stream/{id}

Stream the chaptered video via MUX CDN (or raw video fallback). Gaia uses this to
resolve the playback URL for the native AVPlayer.

### Request

```
GET {GAIA_AITHER_BASE_URL}/api/recording/stream/{assetId}
Authorization: Bearer <token>
```

**Path Parameters**:
- `assetId` (string, required) — Recording session id.

### Response 302 — Redirect to MUX CDN

```
HTTP/1.1 302 Found
Location: https://stream.mux.com/{playback-id}
```

Gaia follows the redirect to obtain the playback `URL` and passes it to the
native AVPlayer.

### Response 206 — Partial Content (Range)

```
HTTP/1.1 206 Partial Content
Content-Range: bytes 0-1023/2048
Content-Type: video/mp4
```

Supports `Range` requests for byte-level seeking (delegated to MUX CDN).

### Fallback Behavior

If no chaptered MUX asset exists for the `assetId`, the endpoint serves the raw
MUX asset (existing Spec 004 behavior, unchanged).

### Authentication

Same `Authorization: Bearer` contract as the chapters endpoints (Spec 005).
