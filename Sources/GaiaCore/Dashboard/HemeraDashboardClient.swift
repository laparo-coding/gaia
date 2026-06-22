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

  /// Transport seam: fetches the raw response body for a dashboard route.
  ///
  /// Production wiring supplies an authenticated transport backed by
  /// `DownstreamServiceClient` + `AuthenticationRuntime` (Spec 005), which
  /// attaches `X-API-Key` for Hemera and performs the one-retry-on-`401`
  /// behavior. Tests can supply an in-memory transport. The default transport
  /// uses the injected `URLSession` against `baseURL` (no auth) to preserve the
  /// existing `URLSession`-stub test harness.
  public typealias Transport = @Sendable (_ path: String, _ requestID: String) async throws -> Data

  private let baseURL: URL
  private let cache: DashboardCache<String, DashboardSnapshot>
  private let ttl: TimeInterval
  private let decoder: JSONDecoder
  private let transport: Transport

  public init(
    baseURL: URL,
    session: URLSession = .shared,
    cache: DashboardCache<String, DashboardSnapshot> = DashboardCache(),
    ttl: TimeInterval = 45
  ) {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    self.baseURL = baseURL
    self.cache = cache
    self.ttl = ttl
    self.decoder = decoder
    self.transport = Self.makeSessionTransport(baseURL: baseURL, session: session)
  }

  /// Designated initializer with an injected transport. Use the
  /// `authenticated(...)` factory for production wiring through Spec 005 auth.
  public init(
    baseURL: URL,
    transport: @escaping Transport,
    cache: DashboardCache<String, DashboardSnapshot> = DashboardCache(),
    ttl: TimeInterval = 45
  ) {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    self.baseURL = baseURL
    self.cache = cache
    self.ttl = ttl
    self.decoder = decoder
    self.transport = transport
  }

  /// Builds an authenticated Hemera dashboard client routed through the Spec 005
  /// downstream auth stack. Attaches `X-API-Key` and reuses the one-retry-on-`401`
  /// behavior from `AuthenticationRuntime`/`ServiceAuthorizationCoordinator`.
  public static func authenticated(
    baseURL: URL,
    downstreamClient: DownstreamServiceClient,
    cache: DashboardCache<String, DashboardSnapshot> = DashboardCache(),
    ttl: TimeInterval = 45,
    operation: String = "dashboard:load-snapshot"
  ) -> HemeraDashboardClient {
    let transport: Transport = { path, requestID in
      let result = await downstreamClient.send(
        service: .hemera,
        baseURL: baseURL,
        path: path,
        method: "GET",
        operation: operation,
        requestId: requestID
      )

      if let error = result.error {
        throw error
      }

      guard let response = result.value, response.statusCode == 200 else {
        throw DashboardDataError.transportFailure(
          statusCode: result.value?.statusCode
        )
      }

      return response.body
    }

    return HemeraDashboardClient(
      baseURL: baseURL, transport: transport, cache: cache, ttl: ttl)
  }

  private static func makeSessionTransport(baseURL: URL, session: URLSession) -> Transport {
    { path, _ in
      let url = try Self.makeURL(baseURL: baseURL, path: path)
      let (data, response) = try await session.data(from: url)
      guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw DashboardDataError.transportFailure(
          statusCode: (response as? HTTPURLResponse)?.statusCode)
      }
      return data
    }
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
      async let participants = fetchParticipants(courseID: courseID, requestID: requestID)
      async let status = fetchStatus(requestID: requestID)
      async let system = fetchSystemHealth(requestID: requestID)

      let snapshot = try await composeSnapshot(
        participantsResponse: participants,
        statusResponse: status,
        systemResponse: system,
        now: now
      )
      await cache.store(value: snapshot, for: courseID, now: now, ttl: ttl)
      return snapshot
    } catch {
      // Soft-fail (FR-007): serve usable stale cache when present...
      if let cached = await cache.valueIfUsable(for: courseID, at: now) {
        return cached.markingStale()
      }

      // ...otherwise surface an explicit degraded snapshot. No placeholder/demo
      // runtime data is served on the production path (FR-001/FR-002;
      // Constitution VI).
      return DashboardSnapshot.degraded(courseID: courseID, now: now)
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

  private func fetchParticipants(
    courseID: String, requestID: String
  ) async throws -> ParticipantsResponse {
    try await fetchDecoded(
      path: "/api/dashboard/participants?courseId=\(courseID)",
      requestID: requestID,
      type: ParticipantsResponse.self
    )
  }

  private func fetchStatus(requestID: String) async throws -> StatusResponse {
    try await fetchDecoded(
      path: "/api/dashboard/status", requestID: requestID, type: StatusResponse.self)
  }

  private func fetchSystemHealth(requestID: String) async throws -> SystemHealthMetricsResponse {
    try await fetchDecoded(
      path: "/api/dashboard/system-health", requestID: requestID,
      type: SystemHealthMetricsResponse.self)
  }

  private func fetchDecoded<Value: Decodable>(
    path: String, requestID: String, type: Value.Type
  ) async throws -> Value {
    let data = try await transport(path, requestID)
    return try decoder.decode(Value.self, from: data)
  }

  /// Builds a URL from a route string that may include a leading slash and a
  /// query component. `URL.appendingPathComponent` is not query-aware and would
  /// percent-encode the `?`, so this splits path and query first and uses
  /// `URLComponents` to attach query items correctly.
  private static func makeURL(baseURL: URL, path: String) throws -> URL {
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

/// Structured failures for the dashboard data path (Constitution VI: errors
/// MUST be structured and attributable rather than stringly-typed).
public enum DashboardDataError: Error, Equatable, Sendable {
  /// The downstream transport returned a non-200 status (or no usable response).
  case transportFailure(statusCode: Int?)
}
