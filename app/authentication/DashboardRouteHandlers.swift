import Foundation
import GaiaCore
import os

private let logger = Logger(
  subsystem: "com.laparo.gaia.authentication",
  category: "DashboardRouteHandlers"
)

private struct HemeraCoursesEnvelope: Decodable {
  struct CourseSummary: Decodable {
    let id: String
    let title: String
  }

  let data: [CourseSummary]
}

private struct HemeraCourseDetailEnvelope: Decodable {
  struct CourseDetail: Decodable {
    /// Backward-compatible participant decoding.
    ///
    /// Accepts both the legacy Hemera field layout (`userId`, `name`, `imageUrl`)
    /// and the canonical Gaia contract layout (`id`, `displayName`, `avatarUrl`).
    /// The canonical keys take precedence when both are present.
    struct Participant: Decodable {
      let userId: String
      let name: String
      let imageUrl: String?

      private enum CanonicalCodingKeys: String, CodingKey {
        case userId = "id"
        case name = "displayName"
        case imageUrl = "avatarUrl"
      }

      enum CodingKeys: String, CodingKey {
        case userId
        case name
        case imageUrl
      }

      init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let canonical = try? decoder.container(keyedBy: CanonicalCodingKeys.self)

        // Canonical (contract) keys take precedence; fall back to legacy Hemera keys.
        // Both id/userId and displayName/name are required — throw when absent.
        let resolvedUserId =
          try canonical?.decodeIfPresent(String.self, forKey: .userId)
          ?? container.decodeIfPresent(String.self, forKey: .userId)
        let resolvedName =
          try canonical?.decodeIfPresent(String.self, forKey: .name)
          ?? container.decodeIfPresent(String.self, forKey: .name)

        guard let userId = resolvedUserId, let name = resolvedName else {
          throw DecodingError.dataCorrupted(
            .init(
              codingPath: decoder.codingPath,
              debugDescription: "Participant 'id'/'userId' and 'displayName'/'name' are required"
            )
          )
        }

        self.userId = userId
        self.name = name
        self.imageUrl =
          try canonical?.decodeIfPresent(String.self, forKey: .imageUrl)
          ?? container.decodeIfPresent(String.self, forKey: .imageUrl)
      }
    }

    let id: String
    let title: String
    let participants: [Participant]
  }

  let data: CourseDetail
}

private struct HemeraHealthEnvelope: Decodable {
  struct HealthPayload: Decodable {
    let status: String
    let timestamp: Date
    let version: String
  }

  let data: HealthPayload
}

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

  static func getStatus(
    runtime: AuthenticationRuntime,
    environment: [String: String],
    now: Date = Date()
  ) async -> AuthenticationRouteResponse<DashboardStatusPayload> {
    let health = await fetchHemeraHealth(runtime: runtime, environment: environment, now: now)
    let serviceStatus: DashboardServiceHealth = health?.status == "ok" ? .healthy : .unavailable
    let connectionState: DashboardConnectionState = health == nil ? .disconnected : .connected

    return AuthenticationRouteResponse(
      statusCode: 200,
      body: DashboardStatusPayload(
        connection: .init(
          aither: connectionState.rawValue,
          hemera: connectionState.rawValue),
        system: .init(
          serviceStatus: serviceStatus.rawValue,
          lastUpdatedAt: health?.timestamp ?? now),
        events: .init(transport: "sse", endpoint: statusEventsPath)
      )
    )
  }

  static func getParticipants(
    runtime: AuthenticationRuntime,
    environment: [String: String],
    courseID: String,
    now: Date = Date()
  ) async -> AuthenticationRouteResponse<DashboardParticipantsPayload> {
    guard
      let selectedCourse = await selectCourse(
        runtime: runtime, environment: environment, courseID: courseID, now: now),
      let courseDetail = await fetchCourseDetail(
        runtime: runtime,
        environment: environment,
        courseID: selectedCourse.id,
        now: now)
    else {
      return AuthenticationRouteResponse(
        statusCode: 502,
        body: DashboardParticipantsPayload(
          course: .init(id: courseID, title: ""),
          participants: [],
          cache: .init(isStale: true, ttlSeconds: 45)
        )
      )
    }

    return AuthenticationRouteResponse(
      statusCode: 200,
      body: DashboardParticipantsPayload(
        course: .init(id: courseDetail.id, title: courseDetail.title),
        participants: courseDetail.participants.map {
          .init(id: $0.userId, displayName: $0.name, avatarUrl: $0.imageUrl)
        },
        cache: .init(isStale: false, ttlSeconds: 45)
      )
    )
  }

  static func getSystemHealth(
    runtime: AuthenticationRuntime,
    environment: [String: String],
    now: Date = Date()
  ) async -> AuthenticationRouteResponse<
    DashboardSystemHealthPayload
  > {
    let health = await fetchHemeraHealth(runtime: runtime, environment: environment, now: now)

    return AuthenticationRouteResponse(
      statusCode: 200,
      body: DashboardSystemHealthPayload(
        version: health?.version ?? "",
        serviceStatus: (health?.status == "ok" ? DashboardServiceHealth.healthy : .unavailable)
          .rawValue,
        lastUpdatedAt: health?.timestamp ?? now
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

  private static func hemeraBaseURL(in environment: [String: String]) -> URL? {
    return try? LocalEnvironment.preferredServiceBaseURL(.hemera, in: environment)
  }

  private static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  private static func fetchHemeraHealth(
    runtime: AuthenticationRuntime,
    environment: [String: String],
    now: Date
  ) async -> HemeraHealthEnvelope.HealthPayload? {
    guard let baseURL = hemeraBaseURL(in: environment) else {
      logger.warning(
        "Hemera health check skipped: no base URL resolved from environment"
      )
      return nil
    }

    let client = DownstreamServiceClient(runtime: runtime)
    let result = await client.send(
      service: .hemera,
      baseURL: baseURL,
      path: "/api/health",
      method: "GET",
      operation: "dashboard:system-health",
      requestId: "dashboard-system-health",
      now: now
    )

    guard let response = result.value else {
      logger.error(
        "Hemera health check failed: downstream client returned no response — \(result.error?.localizedDescription ?? "unknown error")"
      )
      return nil
    }

    guard response.statusCode == 200 else {
      logger.warning(
        "Hemera health check returned non-200 status: \(response.statusCode)"
      )
      return nil
    }

    guard let payload = try? decoder().decode(HemeraHealthEnvelope.self, from: response.body).data
    else {
      logger.error("Hemera health check succeeded but response body could not be decoded")
      return nil
    }

    logger.info("Hemera health check OK — status=\(payload.status), version=\(payload.version)")
    return payload
  }

  private static func selectCourse(
    runtime: AuthenticationRuntime,
    environment: [String: String],
    courseID: String,
    now: Date
  ) async -> HemeraCoursesEnvelope.CourseSummary? {
    guard let baseURL = hemeraBaseURL(in: environment) else {
      return nil
    }

    let client = DownstreamServiceClient(runtime: runtime)
    let result = await client.send(
      service: .hemera,
      baseURL: baseURL,
      path: "/api/service/courses?limit=10",
      method: "GET",
      operation: "dashboard:list-courses",
      requestId: "dashboard-course-list",
      now: now
    )

    guard let response = result.value, response.statusCode == 200,
      let envelope = try? decoder().decode(HemeraCoursesEnvelope.self, from: response.body)
    else {
      return nil
    }

    if courseID != "course-123", let requested = envelope.data.first(where: { $0.id == courseID }) {
      return requested
    }

    return envelope.data.first
  }

  private static func fetchCourseDetail(
    runtime: AuthenticationRuntime,
    environment: [String: String],
    courseID: String,
    now: Date
  ) async -> HemeraCourseDetailEnvelope.CourseDetail? {
    guard let baseURL = hemeraBaseURL(in: environment) else {
      return nil
    }

    let client = DownstreamServiceClient(runtime: runtime)
    let result = await client.send(
      service: .hemera,
      baseURL: baseURL,
      path: "/api/service/courses/\(courseID)",
      method: "GET",
      operation: "dashboard:course-detail",
      requestId: "dashboard-course-detail",
      now: now
    )

    guard let response = result.value, response.statusCode == 200,
      let envelope = try? decoder().decode(HemeraCourseDetailEnvelope.self, from: response.body)
    else {
      return nil
    }

    return envelope.data
  }
}
