import Foundation

public enum DownstreamService: String, Sendable {
  case hemera
  case aither
}

public struct ServiceCredential: Equatable, Sendable {
  public let service: DownstreamService
  public let envPrimaryKey: String
  public let envFallbackKey: String?
  public let cacheKey: String
  public let tokenType: TokenType
  public let audience: String
  public let refreshLeewaySeconds: Int

  public init(
    service: DownstreamService,
    envPrimaryKey: String,
    envFallbackKey: String?,
    cacheKey: String,
    tokenType: TokenType,
    audience: String,
    refreshLeewaySeconds: Int
  ) throws {
    guard !envPrimaryKey.isEmpty, !cacheKey.isEmpty, !audience.isEmpty else {
      throw AuthenticationError.missingEnvironmentKey
    }

    guard refreshLeewaySeconds >= 0 else {
      throw AuthenticationError.invalidRefreshLeeway
    }

    self.service = service
    self.envPrimaryKey = envPrimaryKey
    self.envFallbackKey = envFallbackKey
    self.cacheKey = cacheKey
    self.tokenType = tokenType
    self.audience = audience
    self.refreshLeewaySeconds = refreshLeewaySeconds
  }
}

public struct ServiceTokenCache: Equatable, Sendable {
  public let service: DownstreamService
  public let token: String
  public let expiresAt: Date
  public let lastRefreshAt: Date
  public let retryConsumed: Bool

  public init(
    service: DownstreamService,
    token: String,
    expiresAt: Date,
    lastRefreshAt: Date,
    retryConsumed: Bool
  ) throws {
    guard !token.isEmpty, expiresAt > lastRefreshAt else {
      throw AuthenticationError.invalidSessionWindow
    }

    self.service = service
    self.token = token
    self.expiresAt = expiresAt
    self.lastRefreshAt = lastRefreshAt
    self.retryConsumed = retryConsumed
  }

  init(
    uncheckedService service: DownstreamService,
    token: String,
    expiresAt: Date,
    lastRefreshAt: Date,
    retryConsumed: Bool
  ) {
    self.service = service
    self.token = token
    self.expiresAt = expiresAt
    self.lastRefreshAt = lastRefreshAt
    self.retryConsumed = retryConsumed
  }

  public func isExpired(at date: Date) -> Bool {
    expiresAt <= date
  }

  public func needsRefresh(at date: Date, leewaySeconds: Int) -> Bool {
    expiresAt.addingTimeInterval(-TimeInterval(leewaySeconds)) <= date
  }

  public func consumingRetry() -> ServiceTokenCache {
    ServiceTokenCache(
      uncheckedService: service,
      token: token,
      expiresAt: expiresAt,
      lastRefreshAt: lastRefreshAt,
      retryConsumed: true
    )
  }

  public func resettingRetry() -> ServiceTokenCache {
    ServiceTokenCache(
      uncheckedService: service,
      token: token,
      expiresAt: expiresAt,
      lastRefreshAt: lastRefreshAt,
      retryConsumed: false
    )
  }
}

public struct LoadedServiceToken: Equatable, Sendable {
  public let token: String
  public let expiresAt: Date
  public let refreshedAt: Date

  public init(token: String, expiresAt: Date, refreshedAt: Date) {
    self.token = token
    self.expiresAt = expiresAt
    self.refreshedAt = refreshedAt
  }
}

public enum ServiceAuthorizationStatus: String, Sendable {
  case authorized
  case refreshed
  case degraded
}

public struct ServiceAuthorizationResult: Equatable, Sendable {
  public let service: DownstreamService
  public let status: ServiceAuthorizationStatus
  public let retryOnExpiry: Bool
  public let expiresAt: Date?
  public let token: String?
  public let requestId: String

  public init(
    service: DownstreamService,
    status: ServiceAuthorizationStatus,
    retryOnExpiry: Bool,
    expiresAt: Date?,
    token: String?,
    requestId: String
  ) {
    self.service = service
    self.status = status
    self.retryOnExpiry = retryOnExpiry
    self.expiresAt = expiresAt
    self.token = token
    self.requestId = requestId
  }
}

public struct AuthorizedRequestResult<Value: Sendable>: Sendable {
  public let value: Value?
  public let authorization: ServiceAuthorizationResult?
  public let error: AuthenticationError?

  public init(
    value: Value?, authorization: ServiceAuthorizationResult?, error: AuthenticationError?
  ) {
    self.value = value
    self.authorization = authorization
    self.error = error
  }
}
