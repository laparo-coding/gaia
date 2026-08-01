import Foundation

/// Structured error enum for all playback failures (Spec 010, research R5).
///
/// Each case maps to an Aither error code (see `contracts/chapters-api.md`)
/// or a transport/decoding failure. User-facing German messages follow the
/// Hemera informal "Du" communication convention.
public enum PlaybackError: Error, Equatable, Sendable, CaseIterable {
  /// `404 CHAPTERS_NOT_GENERATED` — chapters not yet generated; operator must
  /// trigger regeneration first (FR-004a).
  case chaptersNotGenerated
  /// `404 RECORDING_NOT_FOUND` — no raw recording exists for the assetId.
  case recordingNotFound
  /// `404 FFMETADATA_NOT_FOUND` — no ffmetadata JSON blob exists.
  case ffmetadataNotFound
  /// `404 CHAPTER_NOT_FOUND` — chapterId does not match any chapter.
  case chapterNotFound
  /// `409 RECORDING_IN_PROGRESS` — recording still active; retry later.
  case recordingInProgress
  /// `422 FFMETADATA_INVALID` — ffmetadata JSON failed schema validation.
  case ffmetadataInvalid
  /// `502 REMUX_FAILED` — FFmpeg remux or chapter-count mismatch.
  case remuxFailed
  /// `503 BLOB_STORAGE_UNAVAILABLE` — Vercel Blob Storage read failure.
  case blobStorageUnavailable
  /// `401 UNAUTHORIZED` — missing/invalid Bearer token.
  case unauthorized
  /// `403 FORBIDDEN` — authenticated but not authorized.
  case forbidden
  /// Transport failure (network unreachable, timeout, DNS, etc.).
  case networkFailure
  /// Decoding failure or unexpected response shape (incl. `400 INVALID_REQUEST`,
  /// `500 INTERNAL_ERROR`, missing redirect `Location` header).
  case invalidResponse

  /// User-facing German message (informal "Du", Hemera convention).
  public var localizedMessage: String {
    switch self {
    case .chaptersNotGenerated:
      return "Kapitel noch nicht generiert. Bitte zuerst regenerieren."
    case .recordingNotFound:
      return "Aufnahme nicht gefunden."
    case .ffmetadataNotFound:
      return "Kapitel-Metadaten nicht gefunden."
    case .chapterNotFound:
      return "Kapitel nicht gefunden."
    case .recordingInProgress:
      return "Aufnahme läuft noch. Regeneration später erneut versuchen."
    case .ffmetadataInvalid:
      return "Kapitel-Metadaten ungültig."
    case .remuxFailed:
      return "Video-Regeneration fehlgeschlagen. Erneut versuchen?"
    case .blobStorageUnavailable:
      return "Speicher vorübergehend nicht verfügbar. Erneut versuchen?"
    case .unauthorized:
      return "Nicht autorisiert."
    case .forbidden:
      return "Keine Berechtigung für diese Aktion."
    case .networkFailure:
      return "Netzwerkfehler. Erneut versuchen?"
    case .invalidResponse:
      return "Ungültige Antwort vom Server."
    }
  }

  /// Whether this error is transient and a retry may succeed (research R5).
  public var isRetryable: Bool {
    switch self {
    case .recordingInProgress, .remuxFailed, .blobStorageUnavailable, .networkFailure:
      return true
    default:
      return false
    }
  }

  /// Maps an Aither error envelope code (see `contracts/chapters-api.md`) to
  /// a `PlaybackError`. Returns `nil` for unknown codes (caller falls back to
  /// `.invalidResponse`).
  public static func fromAitherCode(_ code: String) -> PlaybackError? {
    switch code {
    case "CHAPTERS_NOT_GENERATED": return .chaptersNotGenerated
    case "RECORDING_NOT_FOUND": return .recordingNotFound
    case "FFMETADATA_NOT_FOUND": return .ffmetadataNotFound
    case "CHAPTER_NOT_FOUND": return .chapterNotFound
    case "RECORDING_IN_PROGRESS": return .recordingInProgress
    case "FFMETADATA_INVALID": return .ffmetadataInvalid
    case "REMUX_FAILED": return .remuxFailed
    case "BLOB_STORAGE_UNAVAILABLE": return .blobStorageUnavailable
    case "UNAUTHORIZED": return .unauthorized
    case "FORBIDDEN": return .forbidden
    default: return nil
    }
  }
}
