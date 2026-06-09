import Foundation
import GaiaCore

struct DashboardStatusPayload: Codable, Equatable, Sendable {
  struct Connection: Codable, Equatable, Sendable {
    let aither: String
    let hemera: String
  }

  struct System: Codable, Equatable, Sendable {
    let serviceStatus: String
    let lastUpdatedAt: Date
  }

  struct Events: Codable, Equatable, Sendable {
    let transport: String
    let endpoint: String
  }

  let connection: Connection
  let system: System
  let events: Events
}

struct DashboardParticipantsPayload: Codable, Equatable, Sendable {
  struct Course: Codable, Equatable, Sendable {
    let id: String
    let title: String
  }

  struct Participant: Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let avatarUrl: String?
  }

  struct Cache: Codable, Equatable, Sendable {
    let isStale: Bool
    let ttlSeconds: Int
  }

  let course: Course
  let participants: [Participant]
  let cache: Cache
}

struct DashboardSystemHealthPayload: Codable, Equatable, Sendable {
  let version: String
  let serviceStatus: String
  let lastUpdatedAt: Date
}

enum DashboardRouteHandlers {
  static let statusPath = "/api/dashboard/status"
  static let statusEventsPath = "/api/dashboard/status/events"
  static let participantsPath = "/api/dashboard/participants"
  static let systemHealthPath = "/api/dashboard/system-health"

  static func getStatus(now: Date = Date()) -> AuthenticationRouteResponse<DashboardStatusPayload> {
    AuthenticationRouteResponse(
      statusCode: 200,
      body: DashboardStatusPayload(
        connection: .init(
          aither: DashboardConnectionState.connected.rawValue,
          hemera: DashboardConnectionState.connected.rawValue),
        system: .init(serviceStatus: DashboardServiceHealth.healthy.rawValue, lastUpdatedAt: now),
        events: .init(transport: "sse", endpoint: statusEventsPath)
      )
    )
  }

  static func getParticipants(
    courseID: String,
    now: Date = Date()
  ) -> AuthenticationRouteResponse<DashboardParticipantsPayload> {
    return AuthenticationRouteResponse(
      statusCode: 200,
      body: DashboardParticipantsPayload(
        course: .init(id: courseID, title: "Gaia Seminar"),
        participants: [
          .init(id: "user-1", displayName: "Alex Example", avatarUrl: nil),
          .init(id: "user-2", displayName: "Mara Muster", avatarUrl: nil),
          .init(id: "user-3", displayName: "Sam Sample", avatarUrl: nil),
        ],
        cache: .init(isStale: false, ttlSeconds: 45)
      )
    )
  }

  static func getSystemHealth(now: Date = Date()) -> AuthenticationRouteResponse<
    DashboardSystemHealthPayload
  > {
    AuthenticationRouteResponse(
      statusCode: 200,
      body: DashboardSystemHealthPayload(
        version: "1.0.0",
        serviceStatus: DashboardServiceHealth.healthy.rawValue,
        lastUpdatedAt: now
      )
    )
  }

  /// Heartbeat cadence emitted by the SSE endpoint.
  static let statusEventHeartbeatSeconds: UInt64 = 15

  static func getStatusEvents(
    now: Date = Date(),
    isCancelled: @escaping @Sendable () -> Bool = { false }
  ) -> AsyncStream<String> {
    let stream = AsyncStream<String>.makeStream()
    let continuation = stream.continuation

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    let formatter = ISO8601DateFormatter()

    let initialEvent = DashboardStatusEvent(
      type: .connectionChanged,
      timestamp: now,
      connection: .init(
        aither: .connected,
        hemera: .connected
      ),
      system: .init(serviceStatus: .healthy, lastUpdatedAt: now)
    )

    if let initialFrame = encodeStatusFrame(event: initialEvent, encoder: encoder) {
      let initialResult = continuation.yield(initialFrame)
      if case .dropped = initialResult {
        continuation.finish()
        return stream.stream
      }
    } else {
      continuation.finish()
      return stream.stream
    }

    let heartbeatTask = Task { [statusEventHeartbeatSeconds] in
      let cadence = statusEventHeartbeatSeconds
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: cadence * 1_000_000_000)
        if Task.isCancelled || isCancelled() {
          break
        }

        let timestamp = formatter.string(from: Date())
        let result = continuation.yield(": heartbeat \(timestamp)\n\n")
        if case .dropped = result {
          break
        }
      }
      continuation.finish()
    }

    continuation.onTermination = { _ in
      heartbeatTask.cancel()
    }

    return stream.stream
  }

  private static func encodeStatusFrame(
    event: DashboardStatusEvent,
    encoder: JSONEncoder
  ) -> String? {
    guard let data = try? encoder.encode(event),
      let payload = String(data: data, encoding: .utf8)
    else {
      return nil
    }
    return "event: \(event.type.rawValue)\ndata: \(payload)\n\n"
  }
}
