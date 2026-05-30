import Testing

@testable import GaiaCore

struct HemeraServiceAuthorizationScenarioTests {
  @Test
  func hemeraAuthorizationUsesCachedBearerCredentialWhileValid() async throws {
    let cacheStore = ServiceTokenCacheStore()
    let credential = try ServiceCredential(
      service: .hemera,
      envPrimaryKey: AuthTestSupport.hemeraEnvKey,
      envFallbackKey: nil,
      cacheKey: AuthTestSupport.hemeraCacheKey,
      tokenType: .bearer,
      audience: AuthTestSupport.hemeraAudience,
      refreshLeewaySeconds: 60
    )
    let loader = TokenProviderStub(tokens: [
      LoadedServiceToken(
        token: "hemera-token-1",
        expiresAt: AuthTestSupport.expiresAt,
        refreshedAt: AuthTestSupport.issuedAt
      )
    ])
    let authenticator = HemeraServiceAuthenticator(
      credential: credential,
      cacheStore: cacheStore,
      tokenProvider: { credential in
        try await loader.load(credential)
      }
    )

    let first = try await authenticator.authorize(
      operation: "read-courses",
      requestId: AuthTestSupport.requestId,
      now: AuthTestSupport.issuedAt
    )
    let second = try await authenticator.authorize(
      operation: "read-courses",
      requestId: AuthTestSupport.requestId,
      now: AuthTestSupport.issuedAt.addingTimeInterval(30)
    )

    #expect(first.service == .hemera)
    #expect(first.status == .authorized)
    #expect(second.token == "hemera-token-1")
    #expect(await loader.currentCallCount() == 1)
  }
}
