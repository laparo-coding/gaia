import Foundation

public struct AitherServiceAuthenticator: Sendable {
  public let credential: ServiceCredential
  public let cacheStore: ServiceTokenCacheStore
  private let tokenProvider: @Sendable (ServiceCredential) throws -> LoadedServiceToken

  public init(
    credential: ServiceCredential,
    cacheStore: ServiceTokenCacheStore,
    tokenProvider: @escaping @Sendable (ServiceCredential) throws -> LoadedServiceToken
  ) {
    self.credential = credential
    self.cacheStore = cacheStore
    self.tokenProvider = tokenProvider
  }

  public func authorize(
    operation _: String,
    requestId: String,
    now: Date
  ) async throws -> ServiceAuthorizationResult {
    if let cached = await cacheStore.cached(
      for: .aither,
      at: now,
      leewaySeconds: credential.refreshLeewaySeconds
    ) {
      return ServiceAuthorizationResult(
        service: .aither,
        status: .authorized,
        retryOnExpiry: true,
        expiresAt: cached.expiresAt,
        token: cached.token,
        requestId: requestId
      )
    }

    let loaded = try tokenProvider(credential)
    let entry = try ServiceTokenCache(
      service: .aither,
      token: loaded.token,
      expiresAt: loaded.expiresAt,
      lastRefreshAt: loaded.refreshedAt,
      retryConsumed: false
    )
    await cacheStore.store(entry)

    return ServiceAuthorizationResult(
      service: .aither,
      status: .authorized,
      retryOnExpiry: true,
      expiresAt: loaded.expiresAt,
      token: loaded.token,
      requestId: requestId
    )
  }
}
