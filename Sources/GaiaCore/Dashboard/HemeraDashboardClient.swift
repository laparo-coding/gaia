import Foundation

public struct HemeraDashboardClient: DashboardServiceProtocol, Sendable {
  private struct ParticipantsResponse: Decodable {
    struct Course: Decodable {
      let id: String
      let title: String
    }

    struct Participant: Decodable {
      let id: String
      let displayName: String
      let avatarUrl: String?
    }

    struct Cache: Decodable {
      let isStale: Bool
      let ttlSeconds: Int
    }

    let course: Course
    let participants: [Participant]
    let cache: Cache
  }

  private struct StatusResponse: Decodable {
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

  private let baseURL: URL
  private let session: URLSession
  private let cache: DashboardCache<String, DashboardSnapshot>
  private let ttl: TimeInterval
  private let decoder: JSONDecoder

  public init(
    baseURL: URL,
    session: URLSession = .shared,
    cache: DashboardCache<String, DashboardSnapshot> = DashboardCache(),
    ttl: TimeInterval = 45
  ) {
    self.baseURL = baseURL
    self.session = session
    self.cache = cache
    self.ttl = ttl
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  public func loadSnapshot(
    courseID: String,
    requestID: String,
    now: Date = Date()
  ) async -> DashboardSnapshot {
    if let cached = await cache.valueIfUsable(for: courseID, at: now) {
      switch await cache.freshness(for: courseID, at: now) {
      case .fresh:
        return cached
      case .stale:
        return cached.markingStale()
      case .expired, .missing:
        break
      }
    }

    do {
      async let participants = fetchParticipants(courseID: courseID)
      async let status = fetchStatus()
      async let system = fetchSystemHealth()

      let snapshot = try await composeSnapshot(
        participantsResponse: participants,
        statusResponse: status,
        systemResponse: system,
        now: now
      )
      await cache.store(value: snapshot, for: courseID, now: now, ttl: ttl)
      return snapshot
    } catch {
      if let cached = await cache.valueIfUsable(for: courseID, at: now) {
        return cached.markingStale()
      }

      return DashboardSnapshot.demo(courseID: courseID, now: now).markingStale()
    }
  }

  private func composeSnapshot(
    participantsResponse: ParticipantsResponse,
    statusResponse: StatusResponse,
    systemResponse: SystemHealthMetricsResponse,
    now: Date
  ) throws -> DashboardSnapshot {
    let course = DashboardCourse(
      id: participantsResponse.course.id,
      title: participantsResponse.course.title
    )

    let participants = participantsResponse.participants.map {
      DashboardParticipant(
        id: $0.id,
        displayName: $0.displayName,
        avatarURL: $0.avatarUrl.flatMap(URL.init(string:))
      )
    }

    return DashboardSnapshot(
      course: course,
      participants: participants,
      connection: DashboardConnectionStatus(
        aither: statusResponse.connection.aither,
        hemera: statusResponse.connection.hemera
      ),
      system: DashboardSystemMetrics(
        version: systemResponse.version,
        serviceStatus: systemResponse.serviceStatus,
        lastUpdatedAt: systemResponse.lastUpdatedAt
      ),
      isStale: participantsResponse.cache.isStale,
      warningMessage: participantsResponse.cache.isStale ? "Daten evtl. veraltet" : nil
    )
  }

  private func fetchParticipants(courseID: String) async throws -> ParticipantsResponse {
    try await fetchDecoded(
      path: "/api/dashboard/participants?courseId=\(courseID)",
      type: ParticipantsResponse.self
    )
  }

  private func fetchStatus() async throws -> StatusResponse {
    try await fetchDecoded(path: "/api/dashboard/status", type: StatusResponse.self)
  }

  private func fetchSystemHealth() async throws -> SystemHealthMetricsResponse {
    try await fetchDecoded(
      path: "/api/dashboard/system-health", type: SystemHealthMetricsResponse.self)
  }

  private func fetchDecoded<Value: Decodable>(path: String, type: Value.Type) async throws -> Value
  {
    let url = try makeURL(path: path)
    let (data, response) = try await session.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }
    return try decoder.decode(Value.self, from: data)
  }

  /// Builds a URL from a route string that may include a leading slash and a
  /// query component. `URL.appendingPathComponent` is not query-aware and would
  /// percent-encode the `?`, so this splits path and query first and uses
  /// `URLComponents` to attach query items correctly.
  private func makeURL(path: String) throws -> URL {
    let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let routePath: String
    let routeQuery: String?
    if let querySeparator = trimmedPath.firstIndex(of: "?") {
      routePath = String(trimmedPath[..<querySeparator])
      let queryStart = trimmedPath.index(after: querySeparator)
      routeQuery = queryStart < trimmedPath.endIndex ? String(trimmedPath[queryStart...]) : nil
    } else {
      routePath = trimmedPath
      routeQuery = nil
    }

    let routeURL = routePath.isEmpty ? baseURL : baseURL.appendingPathComponent(routePath)
    guard let scheme = routeURL.scheme else {
      throw URLError(.badURL)
    }
    _ = scheme

    if let routeQuery, !routeQuery.isEmpty {
      guard var components = URLComponents(url: routeURL, resolvingAgainstBaseURL: false) else {
        throw URLError(.badURL)
      }
      let percentDecoded = routeQuery.removingPercentEncoding ?? routeQuery
      components.percentEncodedQuery = percentDecoded
      guard let composed = components.url else {
        throw URLError(.badURL)
      }
      return composed
    }

    return routeURL
  }
}

private struct SystemHealthMetricsResponse: Decodable {
  let version: String
  let serviceStatus: DashboardServiceHealth
  let lastUpdatedAt: Date
}
