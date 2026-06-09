import Foundation

public struct ConnectionStatusMonitor: Sendable {
  public let baseURL: URL
  private let session: URLSession
  private let eventsEndpointPath: String
  private let reconnectBackoff: [TimeInterval]
  private let sleep: @Sendable (UInt64) async throws -> Void

  public init(
    baseURL: URL,
    session: URLSession = .shared,
    eventsEndpointPath: String = "/api/dashboard/status/events",
    reconnectBackoff: [TimeInterval] = [0.5, 1, 2, 5],
    sleep: @escaping @Sendable (UInt64) async throws -> Void = { nanoseconds in
      try await Task.sleep(nanoseconds: nanoseconds)
    }
  ) {
    self.baseURL = baseURL
    self.session = session
    self.eventsEndpointPath = eventsEndpointPath
    self.reconnectBackoff = reconnectBackoff
    self.sleep = sleep
  }

  public func loadBootstrapSnapshot(courseID: String = "course-123") async throws
    -> DashboardSnapshot
  {
    let url = baseURL.appendingPathComponent("api/dashboard/status")
    let (data, response) = try await session.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    struct BootstrapResponse: Decodable {
      struct Connection: Decodable {
        let aither: DashboardConnectionState
        let hemera: DashboardConnectionState
      }

      struct System: Decodable {
        let serviceStatus: DashboardServiceHealth
        let lastUpdatedAt: Date
      }

      struct Events: Decodable {
        let transport: String
        let endpoint: String
      }

      let connection: Connection
      let system: System
      let events: Events
    }

    let payload = try decoder.decode(BootstrapResponse.self, from: data)
    return DashboardSnapshot(
      course: DashboardCourse(id: courseID, title: "Gaia Seminar"),
      participants: [],
      connection: DashboardConnectionStatus(
        aither: payload.connection.aither,
        hemera: payload.connection.hemera
      ),
      system: DashboardSystemMetrics(
        version: "1.0.0",
        serviceStatus: payload.system.serviceStatus,
        lastUpdatedAt: payload.system.lastUpdatedAt
      )
    )
  }

  public func eventStream() -> AsyncThrowingStream<DashboardStatusEvent, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var attempt = 0
        var buffer = ""

        outer: while !Task.isCancelled {
          do {
            let request = makeStatusEventRequest()

            let (asyncBytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
              throw URLError(.badServerResponse)
            }

            guard http.statusCode == 200 else {
              throw URLError(.badServerResponse)
            }

            // Reset the backoff attempt once the stream is healthy so that
            // long-lived sessions do not exhaust the reconnect budget on
            // intermittent transient failures.
            attempt = 0

            for try await line in asyncBytes.lines {
              if Task.isCancelled {
                break outer
              }

              let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
              if trimmed.isEmpty {
                if let event = decodeBufferedEvent(buffer: &buffer, decoder: decoder) {
                  continuation.yield(event)
                }
                continue
              }

              if trimmed.hasPrefix(":") {
                buffer = ""
                continue
              }

              if trimmed.hasPrefix("data:") {
                let payload = String(trimmed.dropFirst("data:".count))
                  .trimmingCharacters(in: .whitespacesAndNewlines)
                if buffer.isEmpty {
                  buffer = payload
                } else {
                  buffer += "\n" + payload
                }
              } else if !trimmed.hasPrefix("event:") && !trimmed.hasPrefix("id:") {
                buffer = ""
              }
            }

            if !buffer.isEmpty, let event = decodeBufferedEvent(buffer: &buffer, decoder: decoder) {
              continuation.yield(event)
            }

            continuation.finish(throwing: nil)
            return
          } catch is CancellationError {
            break
          } catch {
            if Task.isCancelled {
              break
            }

            if attempt >= reconnectBackoff.count {
              continuation.finish(throwing: error)
              return
            }

            let delaySeconds = reconnectBackoff[min(attempt, reconnectBackoff.count - 1)]
            attempt += 1
            let delayNanos = UInt64(max(delaySeconds, 0) * 1_000_000_000)
            do {
              try await sleep(delayNanos)
            } catch {
              break
            }
          }
        }

        continuation.finish()
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  public func makeStatusEventRequest(now: Date = Date()) -> URLRequest {
    let endpoint = baseURL.appendingPathComponent(normalizedPath(eventsEndpointPath))
    var request = URLRequest(
      url: endpoint, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 0)
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    request.setValue("no", forHTTPHeaderField: "X-Requested-With")
    return request
  }

  private func decodeBufferedEvent(
    buffer: inout String,
    decoder: JSONDecoder
  ) -> DashboardStatusEvent? {
    guard !buffer.isEmpty else { return nil }
    defer { buffer = "" }

    guard let data = buffer.data(using: .utf8) else { return nil }
    return try? decoder.decode(DashboardStatusEvent.self, from: data)
  }

  func decodeSSELines(from data: Data) -> [String] {
    guard let text = String(data: data, encoding: .utf8) else {
      return []
    }

    return
      text
      .split(omittingEmptySubsequences: false, whereSeparator: \Character.isNewline)
      .map(String.init)
  }

  func decodeSSEEvents(from data: Data) -> [DashboardStatusEvent] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    var events: [DashboardStatusEvent] = []
    var buffer = ""

    for line in decodeSSELines(from: data) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty {
        if let event = decodeBufferedEvent(buffer: &buffer, decoder: decoder) {
          events.append(event)
        }
        continue
      }

      if trimmed.hasPrefix(":") {
        buffer = ""
        continue
      }

      if trimmed.hasPrefix("data:") {
        let payload = String(trimmed.dropFirst("data:".count))
          .trimmingCharacters(in: .whitespacesAndNewlines)
        if buffer.isEmpty {
          buffer = payload
        } else {
          buffer += "\n" + payload
        }
      } else if !trimmed.hasPrefix("event:") && !trimmed.hasPrefix("id:") {
        buffer = ""
      }
    }

    if let trailing = decodeBufferedEvent(buffer: &buffer, decoder: decoder) {
      events.append(trailing)
    }

    return events
  }

  private func normalizedPath(_ path: String) -> String {
    if path.hasPrefix("/") {
      return String(path.dropFirst())
    }

    return path
  }
}
