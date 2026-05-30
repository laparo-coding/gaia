import Foundation
import Testing

@testable import GaiaCore

struct DownstreamServiceClientTests {
  @Test
  func hemeraRequestsUseSharedApiKeyHeader() async throws {
    let runtime = try makeRuntime(
      hemeraTokens: [
        LoadedServiceToken(
          token: "hemera-shared-api-key",
          expiresAt: AuthTestSupport.expiresAt,
          refreshedAt: AuthTestSupport.issuedAt
        )
      ],
      aitherTokens: []
    )

    let client = DownstreamServiceClient(runtime: runtime) { request in
      #expect(request.value(forHTTPHeaderField: "X-API-Key") == "hemera-shared-api-key")
      #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
      #expect(request.url?.absoluteString == "http://localhost:3000/api/service/courses")

      let url = try #require(request.url)
      let response = try #require(
        HTTPURLResponse(
          url: url,
          statusCode: 200,
          httpVersion: nil,
          headerFields: ["Content-Type": "application/json"]
        )
      )
      return (Data("[]".utf8), response)
    }

    let result = await client.send(
      service: .hemera,
      baseURL: URL(string: "http://localhost:3000")!,
      path: "/api/service/courses",
      method: "GET",
      operation: "read-courses",
      requestId: AuthTestSupport.requestId,
      now: AuthTestSupport.issuedAt
    )

    #expect(result.value?.statusCode == 200)
    #expect(result.authorization?.status == .authorized)
    #expect(result.error == nil)
  }

  @Test
  func aitherRequestsUseBearerAuthorizationHeader() async throws {
    let runtime = try makeRuntime(
      hemeraTokens: [],
      aitherTokens: [
        LoadedServiceToken(
          token: "aither-sync-token",
          expiresAt: AuthTestSupport.expiresAt,
          refreshedAt: AuthTestSupport.issuedAt
        )
      ]
    )

    let client = DownstreamServiceClient(runtime: runtime) { request in
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer aither-sync-token")
      #expect(request.value(forHTTPHeaderField: "X-API-Key") == nil)
      #expect(request.httpMethod == "POST")
      #expect(request.url?.absoluteString == "http://localhost:3500/api/sync")

      let url = try #require(request.url)
      let response = try #require(
        HTTPURLResponse(
          url: url,
          statusCode: 202,
          httpVersion: nil,
          headerFields: ["Content-Type": "application/json"]
        )
      )
      return (Data("{\"success\":true}".utf8), response)
    }

    let result = await client.send(
      service: .aither,
      baseURL: URL(string: "http://localhost:3500")!,
      path: "/api/sync",
      method: "POST",
      operation: "trigger-sync",
      requestId: AuthTestSupport.requestId,
      now: AuthTestSupport.issuedAt
    )

    #expect(result.value?.statusCode == 202)
    #expect(result.authorization?.status == .authorized)
    #expect(result.error == nil)
  }

  private func makeRuntime(
    hemeraTokens: [LoadedServiceToken],
    aitherTokens: [LoadedServiceToken]
  ) throws -> AuthenticationRuntime {
    let cacheStore = ServiceTokenCacheStore()
    let telemetry = AuthenticationTelemetry()
    let sessionManager = AuthenticationSessionManager()
    let authenticationBaseURL = try #require(URL(string: "http://127.0.0.1:8080"))
    let interactiveProvider = StaticInteractiveAuthenticationProvider(
      authenticationBaseURL: authenticationBaseURL
    )

    let hemeraCredential = try ServiceCredential(
      service: .hemera,
      envPrimaryKey: "HEMERA_SERVICE_API_KEY",
      envFallbackKey: "HEMERA_SERVICE_TOKEN",
      cacheKey: AuthTestSupport.hemeraCacheKey,
      tokenType: .bearer,
      audience: AuthTestSupport.hemeraAudience,
      refreshLeewaySeconds: 60
    )
    let aitherCredential = try ServiceCredential(
      service: .aither,
      envPrimaryKey: "AITHER_SYNC_TOKEN",
      envFallbackKey: "AITHER_SERVICE_TOKEN",
      cacheKey: AuthTestSupport.aitherCacheKey,
      tokenType: .bearer,
      audience: AuthTestSupport.aitherAudience,
      refreshLeewaySeconds: 60
    )

    let hemeraLoader = TokenProviderStub(tokens: hemeraTokens)
    let aitherLoader = TokenProviderStub(tokens: aitherTokens)

    return AuthenticationRuntime(
      sessionManager: sessionManager,
      interactiveProvider: interactiveProvider,
      serviceCoordinator: ServiceAuthorizationCoordinator(
        cacheStore: cacheStore,
        hemeraAuthenticator: HemeraServiceAuthenticator(
          credential: hemeraCredential,
          cacheStore: cacheStore,
          tokenProvider: { credential in
            try await hemeraLoader.load(credential)
          }
        ),
        aitherAuthenticator: AitherServiceAuthenticator(
          credential: aitherCredential,
          cacheStore: cacheStore,
          tokenProvider: { credential in
            try await aitherLoader.load(credential)
          }
        ),
        telemetry: telemetry
      )
    )
  }
}
