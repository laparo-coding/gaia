import Testing

@testable import GaiaCore

struct ServiceTokenCacheTests {
  @Test
  func serviceCredentialValidatesCoreFields() throws {
    let credential = try ServiceCredential(
      service: .hemera,
      envPrimaryKey: AuthTestSupport.hemeraEnvKey,
      envFallbackKey: nil,
      cacheKey: AuthTestSupport.hemeraCacheKey,
      tokenType: .bearer,
      audience: AuthTestSupport.hemeraAudience,
      refreshLeewaySeconds: 60
    )

    #expect(credential.cacheKey == AuthTestSupport.hemeraCacheKey)

    #expect(throws: AuthenticationError.self) {
      _ = try ServiceCredential(
        service: .aither,
        envPrimaryKey: "",
        envFallbackKey: nil,
        cacheKey: AuthTestSupport.aitherCacheKey,
        tokenType: .bearer,
        audience: AuthTestSupport.aitherAudience,
        refreshLeewaySeconds: -1
      )
    }
  }

  @Test
  func cacheDetectsExpiryAndRefreshWindow() throws {
    let cache = try ServiceTokenCache(
      service: .hemera,
      token: "token-1",
      expiresAt: AuthTestSupport.expiry(after: AuthTestSupport.issuedAt, seconds: 300),
      lastRefreshAt: AuthTestSupport.issuedAt,
      retryConsumed: false
    )

    #expect(cache.isExpired(at: AuthTestSupport.issuedAt.addingTimeInterval(600)))
    #expect(
      cache.needsRefresh(at: AuthTestSupport.issuedAt.addingTimeInterval(250), leewaySeconds: 60))
  }

  @Test
  func cacheCanConsumeRetryOncePerRequest() throws {
    let cache = try ServiceTokenCache(
      service: .aither,
      token: "token-2",
      expiresAt: AuthTestSupport.expiresAt,
      lastRefreshAt: AuthTestSupport.issuedAt,
      retryConsumed: false
    )

    let updated = cache.consumingRetry()

    #expect(updated.retryConsumed)
    #expect(updated.resettingRetry().retryConsumed == false)
  }
}
