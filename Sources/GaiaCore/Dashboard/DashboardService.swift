import Foundation

public actor DashboardService: DashboardServiceProtocol {
  private let client: HemeraDashboardClient
  private let cache: DashboardCache<String, DashboardSnapshot>

  public init(client: HemeraDashboardClient, cache: DashboardCache<String, DashboardSnapshot>) {
    self.client = client
    self.cache = cache
  }

  /// Builds a live dashboard service wired to real Hemera data through the
  /// Spec 005 auth stack (Spec 009).
  ///
  /// The Hemera base URL is resolved from `environment` using runtime-aware,
  /// Docker-aware defaults with optional overrides.
  ///
  /// - Throws: `LocalEnvironment.ConfigurationError` when configured base URLs
  ///   are invalid.
  public static func live(
    runtime: AuthenticationRuntime,
    environment: [String: String],
    cache: DashboardCache<String, DashboardSnapshot> = DashboardCache(),
    transport: DownstreamServiceClient.Transport? = nil
  ) throws -> DashboardService {
    let baseURL = try LocalEnvironment.preferredServiceBaseURL(.hemera, in: environment)
    let ttl = LocalEnvironment.dashboardCacheTTL(in: environment)

    let downstreamClient: DownstreamServiceClient
    if let transport {
      downstreamClient = DownstreamServiceClient(runtime: runtime, transport: transport)
    } else {
      downstreamClient = DownstreamServiceClient(runtime: runtime)
    }

    let client = HemeraDashboardClient.authenticated(
      baseURL: baseURL,
      downstreamClient: downstreamClient,
      cache: cache,
      ttl: ttl
    )

    return DashboardService(client: client, cache: cache)
  }

  public func loadSnapshot(
    courseID: String,
    requestID: String,
    now: Date = Date()
  ) async -> DashboardSnapshot {
    let snapshot = await client.loadSnapshot(courseID: courseID, requestID: requestID, now: now)
    await cache.store(value: snapshot, for: courseID, now: now, ttl: 45)
    return snapshot
  }
}
