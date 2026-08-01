import Foundation

@testable import GaiaCore

/// Shared helpers for Spec 010 (timestamp playback) tests: builds a real
/// `AuthenticationRuntime`/`DownstreamServiceClient` wired with stub Aither
/// tokens, and provides canonical JSON fixtures for the chapter endpoints.
enum PlaybackTestSupport {
  static let now = Date(timeIntervalSince1970: 1_717_000_000)
  static let expiresAt = Date(timeIntervalSince1970: 1_717_003_600)
  static let aitherBaseURL = requireURL("https://aither.test.example.com")

  static func requireURL(_ string: String) -> URL {
    guard let url = URL(string: string) else {
      preconditionFailure("Invalid test URL literal: \(string)")
    }
    return url
  }

  static func makeRuntime(aitherToken: String = "aither-test-token") throws
    -> AuthenticationRuntime
  {
    let cacheStore = ServiceTokenCacheStore()
    let telemetry = AuthenticationTelemetry()
    let sessionManager = AuthenticationSessionManager()
    let interactiveProvider = StaticInteractiveAuthenticationProvider(
      authenticationBaseURL: requireURL("http://127.0.0.1:8080")
    )

    let aitherCredential = try makeAitherCredential()
    let aitherLoader = makeTokenLoader(token: aitherToken)

    return AuthenticationRuntime(
      sessionManager: sessionManager,
      interactiveProvider: interactiveProvider,
      serviceCoordinator: try makeServiceCoordinator(
        cacheStore: cacheStore,
        telemetry: telemetry,
        aitherCredential: aitherCredential,
        tokenLoader: aitherLoader
      )
    )
  }

  private static func makeAitherCredential() throws -> ServiceCredential {
    try ServiceCredential(
      service: .aither,
      envPrimaryKey: "AITHER_SYNC_TOKEN",
      envFallbackKey: "AITHER_SERVICE_TOKEN",
      cacheKey: "service.aither",
      tokenType: .bearer,
      audience: "aither",
      refreshLeewaySeconds: 60
    )
  }

  private static func makeTokenLoader(token: String) -> TokenProviderStub {
    TokenProviderStub(
      tokens: Array(
        repeating: LoadedServiceToken(token: token, expiresAt: expiresAt, refreshedAt: now),
        count: 10))
  }

  private static func makeServiceCoordinator(
    cacheStore: ServiceTokenCacheStore,
    telemetry: AuthenticationTelemetry,
    aitherCredential: ServiceCredential,
    tokenLoader: TokenProviderStub
  ) throws -> ServiceAuthorizationCoordinator {
    let hemeraCredential = try ServiceCredential(
      service: .hemera,
      envPrimaryKey: "HEMERA_SERVICE_API_KEY",
      envFallbackKey: "HEMERA_SERVICE_TOKEN",
      cacheKey: "service.hemera",
      tokenType: .bearer,
      audience: "hemera",
      refreshLeewaySeconds: 60
    )
    return ServiceAuthorizationCoordinator(
      cacheStore: cacheStore,
      hemeraAuthenticator: HemeraServiceAuthenticator(
        credential: hemeraCredential,
        cacheStore: cacheStore,
        tokenProvider: { credential in try await tokenLoader.load(credential) }
      ),
      aitherAuthenticator: AitherServiceAuthenticator(
        credential: aitherCredential,
        cacheStore: cacheStore,
        tokenProvider: { credential in try await tokenLoader.load(credential) }
      ),
      telemetry: telemetry
    )
  }

  // MARK: - JSON fixtures

  static func chapterListBody(assetId: String, chapterCount: Int = 2) -> Data {
    let chapters = (0..<chapterCount).map { i in
      "  { \"id\": \(i), \"start\": \(Double(i) * 10.0), \"end\": \(Double(i + 1) * 10.0), \"title\": \"Chapter \(i + 1)\" }"
    }.joined(separator: ",\n")
    return requireData(
      "{\n  \"assetId\": \"\(assetId)\",\n  \"chapters\": [\n\(chapters)\n  ]\n}")
  }

  static func regenerationResultBody(
    assetId: String, muxAssetId: String, chapterCount: Int
  ) -> Data {
    requireData(
      """
      {
        "assetId": "\(assetId)",
        "muxAssetId": "\(muxAssetId)",
        "chapterCount": \(chapterCount)
      }
      """)
  }

  static func errorBody(code: String, message: String) -> Data {
    requireData(
      """
      {
        "success": false,
        "error": { "code": "\(code)", "message": "\(message)" }
      }
      """)
  }

  static func response(
    for request: URLRequest,
    statusCode: Int,
    headerFields: [String: String]? = ["Content-Type": "application/json"]
  ) -> HTTPURLResponse {
    guard let url = request.url,
      let response = HTTPURLResponse(
        url: url, statusCode: statusCode, httpVersion: nil, headerFields: headerFields)
    else {
      preconditionFailure("Invalid test HTTP response")
    }
    return response
  }

  /// Builds `Data` from a known-good static test string without force
  /// unwrapping; a malformed literal is a programmer error and trips the
  /// `precondition` immediately (Constitution VI: no force unwraps).
  private static func requireData(_ string: String) -> Data {
    guard let data = string.data(using: .utf8) else {
      preconditionFailure("Invalid test string literal")
    }
    return data
  }
}

/// Shared actor that records whether every observed request carried the
/// expected Bearer token in its `Authorization` header and counts total
/// requests.
actor BearerHeaderRecorder {
  private let expectedToken: String

  private(set) var allCarriedBearer = true
  private(set) var requestCount = 0

  init(expectedToken: String = "aither-test-token") {
    self.expectedToken = expectedToken
  }

  func record(authorization: String?) {
    requestCount += 1
    let expected = "Bearer \(expectedToken)"
    if authorization != expected {
      allCarriedBearer = false
    }
  }
}
