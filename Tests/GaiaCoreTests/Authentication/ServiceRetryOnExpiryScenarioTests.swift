import Testing

@testable import GaiaCore

struct ServiceRetryOnExpiryScenarioTests {
  @Test
  func expiredCredentialRefreshesOnceAndRetriesOneTime() async throws {
    let cacheStore = ServiceTokenCacheStore()
    let telemetry = AuthenticationTelemetry()
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
        token: "expired-token",
        expiresAt: AuthTestSupport.issuedAt.addingTimeInterval(1),
        refreshedAt: AuthTestSupport.issuedAt
      ),
      LoadedServiceToken(
        token: "fresh-token",
        expiresAt: AuthTestSupport.expiresAt,
        refreshedAt: AuthTestSupport.refreshedAt
      ),
    ])
    let authenticator = HemeraServiceAuthenticator(
      credential: credential,
      cacheStore: cacheStore,
      tokenProvider: { credential in
        try await loader.load(credential)
      }
    )
    let coordinator = ServiceAuthorizationCoordinator(
      cacheStore: cacheStore,
      hemeraAuthenticator: authenticator,
      aitherAuthenticator: AitherServiceAuthenticator(
        credential: try ServiceCredential(
          service: .aither,
          envPrimaryKey: AuthTestSupport.aitherEnvKey,
          envFallbackKey: nil,
          cacheKey: AuthTestSupport.aitherCacheKey,
          tokenType: .bearer,
          audience: AuthTestSupport.aitherAudience,
          refreshLeewaySeconds: 60
        ),
        cacheStore: cacheStore,
        tokenProvider: { credential in
          try await TokenProviderStub(tokens: []).load(credential)
        }
      ),
      telemetry: telemetry
    )

    let result = await coordinator.executeAuthorizedRequest(
      service: .hemera,
      operation: "read-courses",
      requestId: AuthTestSupport.requestId,
      now: AuthTestSupport.issuedAt
    ) { token, attempt in
      if attempt == 0 {
        throw AuthenticationError.downstreamAuthenticationExpired(service: .hemera, signal: "401")
      }

      return token
    }

    #expect(result.value == "fresh-token")
    #expect(result.authorization?.status == .refreshed)
    #expect(await loader.currentCallCount() == 2)
  }
}
