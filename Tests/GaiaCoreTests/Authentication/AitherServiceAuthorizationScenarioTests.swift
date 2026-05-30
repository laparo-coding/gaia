import Testing

@testable import GaiaCore

struct AitherServiceAuthorizationScenarioTests {
  @Test
  func aitherAuthorizationUsesSeparateCredentialPath() async throws {
    let cacheStore = ServiceTokenCacheStore()
    let hemeraCredential = try ServiceCredential(
      service: .hemera,
      envPrimaryKey: AuthTestSupport.hemeraEnvKey,
      envFallbackKey: nil,
      cacheKey: AuthTestSupport.hemeraCacheKey,
      tokenType: .bearer,
      audience: AuthTestSupport.hemeraAudience,
      refreshLeewaySeconds: 60
    )
    let aitherCredential = try ServiceCredential(
      service: .aither,
      envPrimaryKey: AuthTestSupport.aitherEnvKey,
      envFallbackKey: nil,
      cacheKey: AuthTestSupport.aitherCacheKey,
      tokenType: .bearer,
      audience: AuthTestSupport.aitherAudience,
      refreshLeewaySeconds: 60
    )
    let hemeraLoader = TokenProviderStub(tokens: [
      LoadedServiceToken(
        token: "hemera-token-1",
        expiresAt: AuthTestSupport.expiresAt,
        refreshedAt: AuthTestSupport.issuedAt
      )
    ])
    let aitherLoader = TokenProviderStub(tokens: [
      LoadedServiceToken(
        token: "aither-token-1",
        expiresAt: AuthTestSupport.expiresAt,
        refreshedAt: AuthTestSupport.issuedAt
      )
    ])
    let hemeraAuthenticator = HemeraServiceAuthenticator(
      credential: hemeraCredential,
      cacheStore: cacheStore,
      tokenProvider: { credential in
        try await hemeraLoader.load(credential)
      }
    )
    let aitherAuthenticator = AitherServiceAuthenticator(
      credential: aitherCredential,
      cacheStore: cacheStore,
      tokenProvider: { credential in
        try await aitherLoader.load(credential)
      }
    )

    let hemeraResult = try await hemeraAuthenticator.authorize(
      operation: "read-courses",
      requestId: AuthTestSupport.requestId,
      now: AuthTestSupport.issuedAt
    )
    let aitherResult = try await aitherAuthenticator.authorize(
      operation: "control-sync",
      requestId: AuthTestSupport.requestId,
      now: AuthTestSupport.issuedAt
    )

    #expect(hemeraResult.token == "hemera-token-1")
    #expect(aitherResult.token == "aither-token-1")
    #expect(await hemeraLoader.currentCallCount() == 1)
    #expect(await aitherLoader.currentCallCount() == 1)
  }
}
