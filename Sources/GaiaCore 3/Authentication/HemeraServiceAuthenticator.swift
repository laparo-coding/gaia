import Foundation

public struct HemeraServiceAuthenticator: Sendable {
  public let credential: ServiceCredential
  public let cacheStore: ServiceTokenCacheStore
  private let tokenProvider: @Sendable (ServiceCredential) async throws -> LoadedServiceToken

  public init(
    credential: ServiceCredential,
    cacheStore: ServiceTokenCacheStore,
    tokenProvider: @escaping @Sendable (ServiceCredential) async throws -> LoadedServiceToken
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
    let entry = try await cacheStore.getOrLoad(
      for: .hemera,
      at: now,
      leewaySeconds: credential.refreshLeewaySeconds,
      loader: { try await tokenProvider(credential) }
    )

    return ServiceAuthorizationResult(
      service: .hemera,
      status: .authorized,
      retryOnExpiry: true,
      expiresAt: entry.expiresAt,
      token: entry.token,
      requestId: requestId
    )
  }
}
