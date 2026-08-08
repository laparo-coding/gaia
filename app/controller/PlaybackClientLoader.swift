#if canImport(SwiftUI)
import GaiaCore
import SwiftUI

/// Owns the `PlaybackClient` lifecycle for `ControllerRootView`.
///
/// Stored as a `@StateObject` so SwiftUI creates it exactly once per view
/// identity, regardless of how many times the parent view's `init` is called.
/// This prevents the client from being torn down and re-built on spurious view
/// updates and makes the configuration readable in previews/tests by injecting
/// a custom `environment` dictionary.
@MainActor
internal final class PlaybackClientLoader: ObservableObject {
  @Published private(set) var client: PlaybackClient?
  @Published private(set) var configurationError: String?

  init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    let result = Self.makePlaybackClient(environment: environment)
    self.client = result.client
    self.configurationError = result.configurationError
  }

  // MARK: - Factory

  /// Builds a `PlaybackClient` wired through the Spec 005 auth stack.
  ///
  /// In production, both the Aither base URL and the authentication base URL
  /// **must** be configured via environment variables with HTTPS schemes.
  /// HTTP is only permitted on loopback addresses in development or test mode
  /// (Constitution VI).
  ///
  /// Returns `nil` (with a diagnostic message in `configurationError`)
  /// when the environment is misconfigured, allowing the UI to degrade
  /// gracefully instead of crashing.
  private static func makePlaybackClient(
    environment: [String: String]
  ) -> (client: PlaybackClient?, configurationError: String?) {
    let envRuntime = LocalEnvironment.runtimeEnvironment(in: environment)

    // Aither: use the canonical resolution path (production requires explicit config).
    let aitherBaseURL: URL
    do {
      aitherBaseURL = try LocalEnvironment.preferredServiceBaseURL(
        .aither, in: environment
      )
    } catch let error as LocalEnvironment.ConfigurationError {
      let message: String
      switch error {
      case .missingServiceBaseURL:
        message = "Aither base URL is not configured."
      case .invalidServiceBaseURL:
        message = "Aither base URL is invalid."
      }
      return (nil, message)
    } catch {
      return (nil, "Aither base URL: \(error.localizedDescription)")
    }
    if envRuntime == .production, aitherBaseURL.scheme?.lowercased() != "https" {
      return (nil, "Aither base URL must use HTTPS in production.")
    }

    // Auth: require explicit HTTPS URL in production; allow loopback HTTP in development.
    let authBaseURL: URL
    if let url = LocalEnvironment.authBaseURL(in: environment),
      let scheme = url.scheme?.lowercased(),
      let host = url.host,
      (scheme == "https"
        || (scheme == "http"
          && (envRuntime == .development || envRuntime == .test)
          && Self.isLoopbackHost(host)))
    {
      authBaseURL = url
    } else if LocalEnvironment.authBaseURL(in: environment) == nil,
      (envRuntime == .development || envRuntime == .test),
      let fallback = URL(string: "http://127.0.0.1:8080")
    {
      authBaseURL = fallback
    } else {
      return (nil, "GAIA_AUTH_BASE_URL must be set with an HTTPS URL in production.")
    }

    let hemeraToken = environment["HEMERA_SERVICE_API_KEY"]
      ?? environment["HEMERA_SERVICE_TOKEN"]
    let aitherToken = environment["AITHER_SYNC_TOKEN"]
      ?? environment["AITHER_SERVICE_TOKEN"]

    let cacheStore = ServiceTokenCacheStore()
    let telemetry = AuthenticationTelemetry()
    let sessionManager = AuthenticationSessionManager()
    let interactiveProvider = StaticInteractiveAuthenticationProvider(
      authenticationBaseURL: authBaseURL)

    let hemeraCredential = try? ServiceCredential(
      service: .hemera,
      envPrimaryKey: "HEMERA_SERVICE_API_KEY",
      envFallbackKey: "HEMERA_SERVICE_TOKEN",
      cacheKey: "service.hemera",
      tokenType: .bearer,
      audience: "hemera",
      refreshLeewaySeconds: 60
    )
    let aitherCredential = try? ServiceCredential(
      service: .aither,
      envPrimaryKey: "AITHER_SYNC_TOKEN",
      envFallbackKey: "AITHER_SERVICE_TOKEN",
      cacheKey: "service.aither",
      tokenType: .bearer,
      audience: "aither",
      refreshLeewaySeconds: 60
    )

    guard let coordinator = makeServiceCoordinator(
      cacheStore: cacheStore,
      telemetry: telemetry,
      hemeraCredential: hemeraCredential,
      aitherCredential: aitherCredential,
      hemeraToken: hemeraToken,
      aitherToken: aitherToken
    ) else {
      return (nil, "Service credential configuration is invalid.")
    }

    let runtime = AuthenticationRuntime(
      sessionManager: sessionManager,
      interactiveProvider: interactiveProvider,
      serviceCoordinator: coordinator
    )

    let downstream = DownstreamServiceClient(runtime: runtime)
    let resolvedCacheTTL = LocalEnvironment.playbackChapterCacheTTL(in: environment)
    let client = PlaybackClient(
      baseURL: aitherBaseURL,
      downstreamClient: downstream,
      cacheTTL: resolvedCacheTTL
    )
    return (client, nil)
  }

  private static func makeServiceCoordinator(
    cacheStore: ServiceTokenCacheStore,
    telemetry: AuthenticationTelemetry,
    hemeraCredential: ServiceCredential?,
    aitherCredential: ServiceCredential?,
    hemeraToken: String?,
    aitherToken: String?
  ) -> ServiceAuthorizationCoordinator? {
    guard let hemeraCredential, let aitherCredential else {
      return nil
    }
    return ServiceAuthorizationCoordinator(
      cacheStore: cacheStore,
      hemeraAuthenticator: HemeraServiceAuthenticator(
        credential: hemeraCredential,
        cacheStore: cacheStore,
        tokenProvider: makeTokenProvider(service: .hemera, configuredToken: hemeraToken)
      ),
      aitherAuthenticator: AitherServiceAuthenticator(
        credential: aitherCredential,
        cacheStore: cacheStore,
        tokenProvider: makeTokenProvider(service: .aither, configuredToken: aitherToken)
      ),
      telemetry: telemetry
    )
  }

  private static func makeTokenProvider(
    service: DownstreamService,
    configuredToken: String?
  ) -> @Sendable (ServiceCredential) throws -> LoadedServiceToken {
    { _ in
      guard let configuredToken, !configuredToken.isEmpty else {
        throw AuthenticationError.serviceAuthorizationFailed(service: service)
      }

      let now = Date()
      return LoadedServiceToken(
        token: configuredToken,
        expiresAt: now.addingTimeInterval(3600),
        refreshedAt: now
      )
    }
  }

  /// Returns `true` when `host` is a loopback address (case-insensitive).
  ///
  /// Accepts: `localhost`, `127.0.0.1`, `::1`, and the bracketed form `[::1]`.
  private static func isLoopbackHost(_ host: String) -> Bool {
    let lower = host.lowercased()
    return lower == "localhost"
      || lower == "127.0.0.1"
      || lower == "::1"
      || lower == "[::1]"
  }
}
#endif
