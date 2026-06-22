import Foundation

@testable import GaiaCore

/// Shared helpers for Spec 009 (real data connections) tests: builds a real
/// `AuthenticationRuntime`/`DownstreamServiceClient` wired with stub tokens so
/// the dashboard client exercises the actual Spec 005 auth path.
enum RealDataTestSupport {
  static let now = Date(timeIntervalSince1970: 1_717_000_000)
  static let expiresAt = Date(timeIntervalSince1970: 1_717_003_600)
  static let hemeraBaseURL = requireURL("https://hemera.test.example.com")
  static let aitherBaseURL = requireURL("https://aither.test.example.com")

  /// Builds a `URL` from a known-good static test string without force
  /// unwrapping; a malformed literal is a programmer error and trips the
  /// `precondition` immediately (Constitution VI: no force unwraps).
  static func requireURL(_ string: String) -> URL {
    guard let url = URL(string: string) else {
      preconditionFailure("Invalid test URL literal: \(string)")
    }
    return url
  }

  static func makeRuntime(
    hemeraToken: String = "hemera-test-key",
    aitherToken: String = "aither-test-token"
  ) throws -> AuthenticationRuntime {
    let cacheStore = ServiceTokenCacheStore()
    let telemetry = AuthenticationTelemetry()
    let sessionManager = AuthenticationSessionManager()
    let interactiveProvider = StaticInteractiveAuthenticationProvider(
      authenticationBaseURL: requireURL("http://127.0.0.1:8080")
    )

    let hemeraCredential = try ServiceCredential(
      service: .hemera,
      envPrimaryKey: "HEMERA_SERVICE_API_KEY",
      envFallbackKey: "HEMERA_SERVICE_TOKEN",
      cacheKey: "service.hemera",
      tokenType: .bearer,
      audience: "hemera",
      refreshLeewaySeconds: 60
    )
    let aitherCredential = try ServiceCredential(
      service: .aither,
      envPrimaryKey: "AITHER_SYNC_TOKEN",
      envFallbackKey: "AITHER_SERVICE_TOKEN",
      cacheKey: "service.aither",
      tokenType: .bearer,
      audience: "aither",
      refreshLeewaySeconds: 60
    )

    // `loadSnapshot` issues three concurrent Hemera fetches; provide a small
    // pool of identical tokens so a cache stampede across the parallel
    // `getOrLoad` calls cannot exhaust the stub.
    let hemeraLoader = TokenProviderStub(
      tokens: Array(
        repeating: LoadedServiceToken(token: hemeraToken, expiresAt: expiresAt, refreshedAt: now),
        count: 5))
    let aitherLoader = TokenProviderStub(
      tokens: Array(
        repeating: LoadedServiceToken(token: aitherToken, expiresAt: expiresAt, refreshedAt: now),
        count: 5))

    return AuthenticationRuntime(
      sessionManager: sessionManager,
      interactiveProvider: interactiveProvider,
      serviceCoordinator: ServiceAuthorizationCoordinator(
        cacheStore: cacheStore,
        hemeraAuthenticator: HemeraServiceAuthenticator(
          credential: hemeraCredential,
          cacheStore: cacheStore,
          tokenProvider: { credential in try await hemeraLoader.load(credential) }
        ),
        aitherAuthenticator: AitherServiceAuthenticator(
          credential: aitherCredential,
          cacheStore: cacheStore,
          tokenProvider: { credential in try await aitherLoader.load(credential) }
        ),
        telemetry: telemetry
      )
    )
  }

  /// Builds an `AuthenticationRuntime` whose Hemera token loader yields an
  /// already-expired token first and a fresh token on refresh, so a `401`
  /// triggers exactly one refresh + retry.
  static func makeRuntimeWithRefreshableHemera(
    expiredToken: String = "expired-key",
    freshToken: String = "fresh-key"
  ) throws -> AuthenticationRuntime {
    let cacheStore = ServiceTokenCacheStore()
    let telemetry = AuthenticationTelemetry()
    let sessionManager = AuthenticationSessionManager()
    let interactiveProvider = StaticInteractiveAuthenticationProvider(
      authenticationBaseURL: requireURL("http://127.0.0.1:8080")
    )

    let hemeraCredential = try ServiceCredential(
      service: .hemera,
      envPrimaryKey: "HEMERA_SERVICE_API_KEY",
      envFallbackKey: "HEMERA_SERVICE_TOKEN",
      cacheKey: "service.hemera",
      tokenType: .bearer,
      audience: "hemera",
      refreshLeewaySeconds: 60
    )
    let aitherCredential = try ServiceCredential(
      service: .aither,
      envPrimaryKey: "AITHER_SYNC_TOKEN",
      envFallbackKey: "AITHER_SERVICE_TOKEN",
      cacheKey: "service.aither",
      tokenType: .bearer,
      audience: "aither",
      refreshLeewaySeconds: 60
    )

    // First load yields the (about-to-expire) token; every subsequent refresh
    // yields the fresh token. A generous pool absorbs the three concurrent
    // dashboard fetches each performing one refresh on `401`.
    var hemeraTokens: [LoadedServiceToken] = [
      LoadedServiceToken(
        token: expiredToken, expiresAt: now.addingTimeInterval(1), refreshedAt: now)
    ]
    hemeraTokens.append(
      contentsOf: Array(
        repeating: LoadedServiceToken(token: freshToken, expiresAt: expiresAt, refreshedAt: now),
        count: 8))
    let hemeraLoader = TokenProviderStub(tokens: hemeraTokens)
    let aitherLoader = TokenProviderStub(
      tokens: Array(
        repeating: LoadedServiceToken(
          token: "aither-test-token", expiresAt: expiresAt, refreshedAt: now), count: 5))

    return AuthenticationRuntime(
      sessionManager: sessionManager,
      interactiveProvider: interactiveProvider,
      serviceCoordinator: ServiceAuthorizationCoordinator(
        cacheStore: cacheStore,
        hemeraAuthenticator: HemeraServiceAuthenticator(
          credential: hemeraCredential,
          cacheStore: cacheStore,
          tokenProvider: { credential in try await hemeraLoader.load(credential) }
        ),
        aitherAuthenticator: AitherServiceAuthenticator(
          credential: aitherCredential,
          cacheStore: cacheStore,
          tokenProvider: { credential in try await aitherLoader.load(credential) }
        ),
        telemetry: telemetry
      )
    )
  }

  /// Canonical Hemera dashboard JSON bodies for a given course.
  static func participantsBody(courseID: String) -> Data {
    Data(
      """
      {
        "course": { "id": "\(courseID)", "title": "Gaia Seminar" },
        "participants": [
          { "id": "user-1", "displayName": "Real Person One", "avatarUrl": null },
          { "id": "user-2", "displayName": "Real Person Two", "avatarUrl": null }
        ],
        "cache": { "isStale": false, "ttlSeconds": 45 }
      }
      """.utf8)
  }

  static func statusBody() -> Data {
    Data(
      """
      {
        "connection": { "aither": "connected", "hemera": "connected" },
        "system": { "serviceStatus": "healthy", "lastUpdatedAt": "2026-06-16T20:48:00Z" },
        "events": { "transport": "sse", "endpoint": "/api/dashboard/status/events" }
      }
      """.utf8)
  }

  static func systemHealthBody() -> Data {
    Data(
      """
      { "version": "1.0.0", "serviceStatus": "healthy", "lastUpdatedAt": "2026-06-16T20:48:00Z" }
      """.utf8)
  }
}
