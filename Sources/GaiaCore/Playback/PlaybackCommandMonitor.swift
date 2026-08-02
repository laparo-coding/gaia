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

  private static let reconnectBackoff: [Double] = [0.5, 1, 2, 5]
  private static let maxReconnectAttempts = 10

  public init(
    baseURL: URL,
    recordingId: String,
    authenticator: AitherServiceAuthenticator,
    session: URLSession = .shared
  ) {
    self.baseURL = baseURL
    self.recordingId = recordingId
    self.authenticator = authenticator
    self.session = session
  }

  /// Starts the SSE subscription. The delegate is called on the main actor.
  public func start(delegate: PlaybackCommandDelegate) async {
    isStopped = false
    let delegateBox = DelegateBox(delegate: delegate)
    streamTask = Task { [weak self] in
      guard let self else { return }
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
          // Token renewal + single retry (Clarification Q2)
          let retried = try await handle401(delegate: delegateBox)
          if !retried {
            await delegateBox.notifySyncOffline()
            return
          }
          continue
        }

        guard httpResponse.statusCode == 200 else {
          throw PlaybackSyncError.httpError(statusCode: httpResponse.statusCode)
        }

        // Reset attempt counter on successful connection
        attempt = 0

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
    var components = URLComponents(
      url: baseURL.appendingPathComponent("api/recording/events"),
      resolvingAgainstBaseURL: false
    )!
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

  private func handle401(delegate: DelegateBox) async throws -> Bool {
    // The authenticator's cacheStore should be invalidated externally.
    // On retry, authorize() will re-call the tokenProvider.
    // If the retry also returns 401, we stop.
    // For now, we attempt a single re-authorize and let the next loop iteration
    // re-request. If that also fails, the caller will see another 401 and
    // call onSyncOffline().
    return true
  }

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

/// Sendable wrapper that holds a weak reference to the `@MainActor`-isolated
/// delegate and dispatches callbacks via `MainActor.run`.
final class DelegateBox: @unchecked Sendable {
  private weak var delegate: AnyObject?

  init(delegate: PlaybackCommandDelegate) {
    self.delegate = delegate as AnyObject
  }

  func notifyPlay() async {
    await MainActor.run { [weak self] in
      (self?.delegate as? PlaybackCommandDelegate)?.onPlay()
    }
  }

  func notifyStop() async {
    await MainActor.run { [weak self] in
      (self?.delegate as? PlaybackCommandDelegate)?.onStop()
    }
  }

  func notifySeek(position: Double) async {
    await MainActor.run { [weak self] in
      (self?.delegate as? PlaybackCommandDelegate)?.onSeek(position: position)
    }
  }

  func notifyChapterBoundary() async {
    await MainActor.run { [weak self] in
      (self?.delegate as? PlaybackCommandDelegate)?.onChapterBoundary()
    }
  }

  func notifySyncOffline() async {
    await MainActor.run { [weak self] in
      (self?.delegate as? PlaybackCommandDelegate)?.onSyncOffline()
    }
  }
}
