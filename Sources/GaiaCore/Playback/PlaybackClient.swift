import Foundation

/// Typed result for `PlaybackClient` operations, carrying either a success
/// value or a structured `PlaybackError`.
public struct PlaybackClientResult<Value: Sendable>: Sendable {
  public let value: Value?
  public let playbackError: PlaybackError?

  public init(value: Value?, playbackError: PlaybackError?) {
    self.value = value
    self.playbackError = playbackError
  }
}

/// Aither playback client (Spec 010, FR-003 + FR-005 + FR-006 + FR-007).
///
/// `Sendable` network client that consumes Aither's chapter endpoints
/// (`GET`/`POST /api/recording/chapters/[id]`) and the stream endpoint
/// (`GET /api/recording/stream/[id]`). All requests are routed through the
/// Spec 005 auth stack (`DownstreamServiceClient`), which attaches
/// `Authorization: Bearer` and reuses the one-retry-on-`401` behavior.
///
/// A short-lived in-memory chapter list cache (per `assetId`, TTL ≤ 60s,
/// research R3) avoids redundant fetches during a viewing session. The cache
/// is invalidated immediately on a successful regeneration (FR-007).
public struct PlaybackClient: Sendable {
  private let baseURL: URL
  private let downstreamClient: DownstreamServiceClient
  private let cacheTTL: TimeInterval
  private let cache: ChapterListCache

  public init(
    baseURL: URL,
    downstreamClient: DownstreamServiceClient,
    cacheTTL: TimeInterval = LocalEnvironment.defaultPlaybackChapterCacheTTL
  ) {
    self.baseURL = baseURL
    self.downstreamClient = downstreamClient
    self.cacheTTL = cacheTTL
    self.cache = ChapterListCache()
  }

  // MARK: - Chapter List (FR-003)

  /// Fetches the chapter list for `assetId` from Aither
  /// (`GET /api/recording/chapters/[id]`). Returns a cached entry when fresh
  /// (research R3).
  public func fetchChapters(
    assetId: String,
    requestID: String,
    now: Date = Date()
  ) async -> PlaybackClientResult<ChapterListResponse> {
    if let cached = await cache.get(assetId: assetId, now: now, ttl: cacheTTL) {
      return PlaybackClientResult(value: cached, playbackError: nil)
    }

    // Capture the current cache version so a concurrent regeneration
    // that invalidates this assetId will cause the stale write to be
    // discarded (see ChapterListCache.set).
    let version = await cache.currentVersion(for: assetId)

    let path = "api/recording/chapters/\(urlEncode(assetId))"
    let result = await downstreamClient.send(
      service: .aither,
      baseURL: baseURL,
      path: path,
      method: "GET",
      operation: "playback:fetch_chapters",
      requestId: requestID,
      now: now
    )

    return await mapChapterListResponse(
      result, assetId: assetId, now: now, version: version)
  }

  // MARK: - Regeneration (FR-005 + FR-006 + FR-007)

  /// Triggers synchronous regeneration of the chaptered video for `assetId`
  /// (`POST /api/recording/chapters/[id]`). On success, invalidates the
  /// chapter list cache for this `assetId` (FR-007).
  public func regenerate(
    assetId: String,
    requestID: String,
    now: Date = Date()
  ) async -> PlaybackClientResult<ChapterRegenerationResult> {
    let path = "api/recording/chapters/\(urlEncode(assetId))"
    let body = Data("{}".utf8)
    let result = await downstreamClient.send(
      service: .aither,
      baseURL: baseURL,
      path: path,
      method: "POST",
      operation: "playback:regenerate",
      requestId: requestID,
      body: body,
      now: now
    )

    return await mapRegenerationResponse(result, assetId: assetId, now: now)
  }

  // MARK: - Playback URL (research R2)

  /// Resolves the MUX CDN playback URL for `assetId` by following the HTTP 302
  /// redirect from `GET /api/recording/stream/[id]`.
  public func resolvePlaybackURL(
    assetId: String,
    requestID: String,
    now: Date = Date()
  ) async -> PlaybackClientResult<URL> {
    let path = "api/recording/stream/\(urlEncode(assetId))"
    let result = await downstreamClient.send(
      service: .aither,
      baseURL: baseURL,
      path: path,
      method: "GET",
      operation: "playback:resolve_stream",
      requestId: requestID,
      now: now
    )

    return await mapStreamResponse(result)
  }

  // MARK: - Response mapping (T017)

  private func mapChapterListResponse(
    _ result: AuthorizedRequestResult<DownstreamServiceResponse>,
    assetId: String,
    now: Date,
    version: UInt64
  ) async -> PlaybackClientResult<ChapterListResponse> {
    if let error = result.error {
      return PlaybackClientResult(
        value: nil, playbackError: Self.mapAuthError(error))
    }
    guard let response = result.value else {
      return PlaybackClientResult(value: nil, playbackError: .invalidResponse)
    }

    if let playbackError = Self.mapStatusCode(response.statusCode, body: response.body) {
      return PlaybackClientResult(value: nil, playbackError: playbackError)
    }

    do {
      let chapterList = try JSONDecoder().decode(
        ChapterListResponse.self, from: response.body)
      await cache.set(
        assetId: assetId, value: chapterList, now: now, version: version)
      return PlaybackClientResult(value: chapterList, playbackError: nil)
    } catch {
      return PlaybackClientResult(value: nil, playbackError: .invalidResponse)
    }
  }

  private func mapRegenerationResponse(
    _ result: AuthorizedRequestResult<DownstreamServiceResponse>,
    assetId: String,
    now: Date
  ) async -> PlaybackClientResult<ChapterRegenerationResult> {
    if let error = result.error {
      return PlaybackClientResult(
        value: nil, playbackError: Self.mapAuthError(error))
    }
    guard let response = result.value else {
      return PlaybackClientResult(value: nil, playbackError: .invalidResponse)
    }

    if let playbackError = Self.mapStatusCode(response.statusCode, body: response.body) {
      return PlaybackClientResult(value: nil, playbackError: playbackError)
    }

    do {
      let regeneration = try JSONDecoder().decode(
        ChapterRegenerationResult.self, from: response.body)
      // FR-007: invalidate the chapter list cache on successful regeneration.
      await cache.invalidate(assetId: assetId)
      return PlaybackClientResult(value: regeneration, playbackError: nil)
    } catch {
      return PlaybackClientResult(value: nil, playbackError: .invalidResponse)
    }
  }

  private func mapStreamResponse(
    _ result: AuthorizedRequestResult<DownstreamServiceResponse>
  ) async -> PlaybackClientResult<URL> {
    if let error = result.error {
      return PlaybackClientResult(
        value: nil, playbackError: Self.mapAuthError(error))
    }
    guard let response = result.value else {
      return PlaybackClientResult(value: nil, playbackError: .invalidResponse)
    }

    if (300...399).contains(response.statusCode) {
      if let location = response.headers["Location"]
        ?? response.headers["location"],
        let url = URL(string: location)
      {
        return PlaybackClientResult(value: url, playbackError: nil)
      }

      return PlaybackClientResult(value: nil, playbackError: .invalidResponse)
    }

    if let playbackError = Self.mapStatusCode(response.statusCode, body: response.body) {
      return PlaybackClientResult(value: nil, playbackError: playbackError)
    }

    // URLSession follows redirects. Its final response URL is the MUX CDN URL.
    if let url = response.url {
      return PlaybackClientResult(value: url, playbackError: nil)
    }

    return PlaybackClientResult(value: nil, playbackError: .invalidResponse)
  }

  /// Maps an `AuthenticationError` from the auth runtime to a `PlaybackError`.
  private static func mapAuthError(_ error: AuthenticationError) -> PlaybackError {
    switch error {
    case .downstreamAuthenticationExpired, .serviceAuthorizationFailed:
      return .unauthorized
    case .unsafeFailure:
      return .invalidResponse
    default:
      return .networkFailure
    }
  }

  /// Maps an Aither HTTP status code + error envelope body to a `PlaybackError`
  /// (T017, research R5). Returns `nil` for success (2xx) responses.
  private static func mapStatusCode(_ statusCode: Int, body: Data) -> PlaybackError? {
    switch statusCode {
    case 200...299:
      return nil
    case 401:
      return .unauthorized
    case 403:
      return .forbidden
    default:
      // Try to decode the Aither error envelope for the canonical code.
      if let envelope = try? JSONDecoder().decode(
        AitherErrorEnvelope.self, from: body),
        let error = PlaybackError.fromAitherCode(envelope.error.code)
      {
        return error
      }
      // Fall back to status-based mapping for unknown codes.
      switch statusCode {
      case 404: return .invalidResponse
      case 409: return .invalidResponse
      case 422: return .invalidResponse
      case 502: return .remuxFailed
      case 503: return .blobStorageUnavailable
      default: return .invalidResponse
      }
    }
  }

  /// Percent-encodes a value for use as a single URL path segment.
  /// Uses a character set that excludes `/` to prevent path injection.
  private func urlEncode(_ value: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove("/")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
  }
}

// MARK: - Aither error envelope

private struct AitherErrorEnvelope: Decodable {
  struct ErrorBody: Decodable {
    let code: String
    let message: String
  }
  let success: Bool?
  let error: ErrorBody
}

// MARK: - Chapter list cache (research R3)

/// Versioned in-memory cache for chapter lists (research R3).
///
/// Each ``regenerate`` call increments a per-asset version counter.
/// A ``fetchChapters`` call captures the version before its network
/// request; the subsequent ``set`` is silently discarded when the
/// current version has changed (i.e. a regeneration happened in
/// flight). This prevents stale pre-regeneration data from overwriting
/// the invalidated cache (FR-007).
private actor ChapterListCache {
  private struct Entry {
    let value: ChapterListResponse
    let storedAt: Date
    let version: UInt64
  }
  private var entries: [String: Entry] = [:]
  private var versions: [String: UInt64] = [:]

  func currentVersion(for assetId: String) -> UInt64 {
    versions[assetId, default: 0]
  }

  func get(assetId: String, now: Date, ttl: TimeInterval) -> ChapterListResponse? {
    guard let entry = entries[assetId] else { return nil }
    if now.timeIntervalSince(entry.storedAt) > ttl {
      entries[assetId] = nil
      return nil
    }
    guard entry.version == versions[assetId, default: 0] else {
      entries[assetId] = nil
      return nil
    }
    return entry.value
  }

  func set(
    assetId: String, value: ChapterListResponse, now: Date, version: UInt64
  ) {
    // Discard stale writes from fetches that started before a
    // regeneration invalidated this asset.
    guard version == versions[assetId, default: 0] else { return }
    entries[assetId] = Entry(value: value, storedAt: now, version: version)
  }

  func invalidate(assetId: String) {
    versions[assetId, default: 0] += 1
    entries[assetId] = nil
  }
}
