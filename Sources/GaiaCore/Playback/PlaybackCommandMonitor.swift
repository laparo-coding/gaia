import Foundation

/// SSE command payload parsed from Aither's `event: command` messages.
///
/// Mirrors Aither's `SSECommand` type (Spec 004 + Spec 010):
/// - `{"action":"play"}`
/// - `{"action":"stop"}`
/// - `{"action":"seek","position":12.5}`
/// - `{"action":"chapter-boundary","chapterId":0,"nextChapterId":1}`
public enum PlaybackSSECommand: Sendable {
  case play
  case stop
  case seek(position: Double)
  case chapterBoundary(chapterId: Int, nextChapterId: Int?)
}

/// Actor that subscribes to Aither's SSE playback command channel and
/// forwards commands to a `PlaybackCommandDelegate`.
///
/// Uses `URLSession.bytes(for:)` for SSE streaming (same pattern as
/// `ConnectionStatusMonitor`). Runs on a background task; delegate callbacks
/// are dispatched to `@MainActor` via `Task { @MainActor in ... }` per event
/// (Spec 011, NFR-001).
///
/// Reconnect with backoff `[0.5, 1, 2, 5]` seconds, max 10 attempts (NFR-003).
/// On exhaustion, calls `delegate.onSyncOffline()`.
public actor PlaybackCommandMonitor {
  private let baseURL: URL
  private let recordingId: String
  private let authenticator: AitherServiceAuthenticator
  private let session: URLSession

  private var streamTask: Task<Void, Never>?
  private var isStopped = false
  private var consecutiveAuthFailures = 0

  private static let reconnectBackoff: [Double] = [0.5, 1, 2, 5]
  private static let maxReconnectAttempts = 10
  /// Maximum consecutive 401 responses before going offline immediately.
  private static let maxAuthRetries = 2

  /// Maximum allowed length for a `recordingId` (UUIDs are 36 chars).
  private static let maxRecordingIdLength = 128

  /// Allowed character set for `recordingId`: alphanumeric, hyphen, underscore, dot.
  private static let allowedRecordingIdCharset: CharacterSet = {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-_.")
    return allowed.inverted
  }()

  public init(
    baseURL: URL,
    recordingId: String,
    authenticator: AitherServiceAuthenticator,
    session: URLSession = .shared
  ) {
    self.baseURL = baseURL
    self.recordingId = Self.normalizedRecordingId(recordingId)
    self.authenticator = authenticator
    self.session = session
  }

  /// Validates and normalizes a `recordingId` for safe use in URL query items
  /// and request metadata. Rejects values that are empty, exceed the length
  /// limit, or contain characters outside the allowed charset.
  ///
  /// - Returns: The trimmed original string if valid, or `"invalid"` as a
  ///   safe fallback that will still produce a well-formed request.
  public static func normalizedRecordingId(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          trimmed.count <= Self.maxRecordingIdLength,
          trimmed.rangeOfCharacter(from: Self.allowedRecordingIdCharset) == nil
    else {
      return "invalid"
    }
    return trimmed
  }

  /// Starts the SSE subscription. The delegate is called on the main actor.
  ///
  /// The spawned `Task` holds a strong reference to the actor for the
  /// duration of the stream. Call `stop()` to cancel the task and break
  /// the reference cycle.
  public func start(delegate: any PlaybackCommandDelegate) async {
    isStopped = false
    let delegateBox = DelegateBox(delegate: delegate)
    streamTask = Task {
      await self.runEventStream(delegateBox: delegateBox)
    }
  }

  /// Stops the SSE subscription and cancels the background task.
  public func stop() async {
    isStopped = true
    streamTask?.cancel()
    streamTask = nil
  }

  // MARK: - SSE Stream

  private func runEventStream(delegateBox: DelegateBox) async {
    var attempt = 0

    while !isStopped {
      do {
        let request = try await makeRequest()
        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
          throw PlaybackSyncError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
          consecutiveAuthFailures += 1
          if consecutiveAuthFailures >= Self.maxAuthRetries {
            await delegateBox.notifySyncOffline()
            return
          }
          // Invalidate cached token so the next authorize() call fetches fresh credentials.
          await authenticator.cacheStore.invalidate(service: .aither)
          attempt = await reconnect(attempt: attempt, delegate: delegateBox)
          continue
        }

        guard httpResponse.statusCode == 200 else {
          throw PlaybackSyncError.httpError(statusCode: httpResponse.statusCode)
        }

        // Reset attempt and auth-failure counters on successful connection
        attempt = 0
        consecutiveAuthFailures = 0

        // Parse SSE lines
        var buffer = ""
        for try await line in asyncBytes.lines {
          if Task.isCancelled || isStopped { return }

          let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

          if trimmed.isEmpty {
            // Blank line → dispatch buffered event
            if !buffer.isEmpty {
              if let command = parseCommand(data: buffer) {
                await dispatchCommand(command, to: delegateBox)
              }
              buffer = ""
            }
          } else if trimmed.hasPrefix("data:") {
            let payload = String(trimmed.dropFirst("data:".count))
              .trimmingCharacters(in: .whitespacesAndNewlines)
            if buffer.isEmpty {
              buffer = payload
            } else {
              buffer += "\n" + payload
            }
          } else if trimmed.hasPrefix(":") {
            // Comment / heartbeat — ignore
            continue
          } else if trimmed.hasPrefix("event:") || trimmed.hasPrefix("id:") {
            // Event type / ID — we only parse `data:` for commands
            continue
          }
        }

        // Stream ended — reconnect
        if isStopped { return }
        attempt = await reconnect(attempt: attempt, delegate: delegateBox)
      } catch {
        if Task.isCancelled || isStopped { return }
        attempt = await reconnect(attempt: attempt, delegate: delegateBox)
      }
    }
  }

  // MARK: - Request

  private func makeRequest() async throws -> URLRequest {
    guard var components = URLComponents(
      url: baseURL.appendingPathComponent("api/recording/events"),
      resolvingAgainstBaseURL: false
    ) else {
      throw PlaybackSyncError.invalidURL
    }
    components.queryItems = [URLQueryItem(name: "recordingId", value: recordingId)]

    guard let url = components.url else {
      throw PlaybackSyncError.invalidURL
    }

    var request = URLRequest(url: url)
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    request.timeoutInterval = 0

    let authResult = try await authenticator.authorize(
      operation: "playback-sse",
      requestId: "sse-\(recordingId)",
      now: Date()
    )
    if let token = authResult.token {
      request.setValue(
        "Bearer \(token)",
        forHTTPHeaderField: "Authorization"
      )
    }

    return request
  }

  // MARK: - 401 Handling

  // 401 recovery is handled inline in `runEventStream`:
  // 1. Increment `consecutiveAuthFailures`.
  // 2. If the limit (`maxAuthRetries`) is exceeded, go offline immediately.
  // 3. Otherwise, invalidate the Aither token cache so the next `authorize()`
  //    call fetches fresh credentials, then reconnect with backoff.

  // MARK: - Reconnect

  private func reconnect(
    attempt: Int,
    delegate: DelegateBox
  ) async -> Int {
    if attempt >= Self.maxReconnectAttempts {
      await delegate.notifySyncOffline()
      isStopped = true
      return attempt
    }

    let delaySeconds = Self.reconnectBackoff[
      min(attempt, Self.reconnectBackoff.count - 1)
    ]
    let delayNanos = UInt64(delaySeconds * 1_000_000_000)
    do {
      try await Task.sleep(nanoseconds: delayNanos)
    } catch {
      // Task cancelled during sleep — stop
      isStopped = true
    }
    return attempt + 1
  }

  // MARK: - Parsing

  private func parseCommand(data: String) -> PlaybackSSECommand? {
    Self.parseCommandForTesting(data: data)
  }

  /// Test hook for parsing SSE command data. Used by unit tests.
  public static func parseCommandForTesting(data: String) -> PlaybackSSECommand? {
    guard let jsonData = data.data(using: .utf8) else { return nil }
    guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
      return nil
    }
    guard let action = json["action"] as? String else { return nil }

    switch action {
    case "play":
      return .play
    case "stop":
      return .stop
    case "seek":
      guard let position = json["position"] as? Double else { return nil }
      return .seek(position: position)
    case "chapter-boundary":
      let chapterId = json["chapterId"] as? Int ?? 0
      let nextChapterId = json["nextChapterId"] as? Int
      return .chapterBoundary(chapterId: chapterId, nextChapterId: nextChapterId)
    default:
      return nil
    }
  }

  /// Test hook for reconnect backoff sequence.
  public static var reconnectBackoffForTesting: [Double] {
    reconnectBackoff
  }

  /// Test hook for max reconnect attempts.
  public static var maxReconnectAttemptsForTesting: Int {
    maxReconnectAttempts
  }

  /// Test hook for max auth retries before going offline.
  public static var maxAuthRetriesForTesting: Int {
    maxAuthRetries
  }

  // MARK: - Dispatch

  private func dispatchCommand(
    _ command: PlaybackSSECommand,
    to delegateBox: DelegateBox
  ) async {
    switch command {
    case .play:
      await delegateBox.notifyPlay()
    case .stop:
      await delegateBox.notifyStop()
    case .seek(let position):
      await delegateBox.notifySeek(position: position)
    case .chapterBoundary:
      await delegateBox.notifyChapterBoundary()
    }
  }
}

// MARK: - Errors

enum PlaybackSyncError: Error, Sendable {
  case invalidURL
  case invalidResponse
  case httpError(statusCode: Int)
}

// MARK: - DelegateBox (Sendable wrapper for @MainActor delegate)

/// Actor that holds a weak reference to the `@MainActor`-isolated delegate
/// and dispatches callbacks via `MainActor.run`.
///
/// Using an actor (instead of `@unchecked Sendable`) gives us:
/// - Automatic `Sendable` conformance without compiler bypasses.
/// - Safe mutable state (`weak var delegate`) protected by actor isolation.
/// - Typed storage (`any PlaybackCommandDelegate`) instead of `AnyObject`.
actor DelegateBox {
  private weak var delegate: (any PlaybackCommandDelegate)?

  init(delegate: any PlaybackCommandDelegate) {
    self.delegate = delegate
  }

  nonisolated func notifyPlay() async {
    let d = await delegate
    await MainActor.run { d?.onPlay() }
  }

  nonisolated func notifyStop() async {
    let d = await delegate
    await MainActor.run { d?.onStop() }
  }

  nonisolated func notifySeek(position: Double) async {
    let d = await delegate
    await MainActor.run { d?.onSeek(position: position) }
  }

  nonisolated func notifyChapterBoundary() async {
    let d = await delegate
    await MainActor.run { d?.onChapterBoundary() }
  }

  nonisolated func notifySyncOffline() async {
    let d = await delegate
    await MainActor.run { d?.onSyncOffline() }
  }
}
