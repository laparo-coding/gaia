import Foundation

public enum AuthProvider: String, Sendable {
  case interactive
  case service
}

public enum TokenType: String, Sendable {
  case bearer
}

public enum AuthAudience: String, Sendable {
  case gaia
  case hemera
  case aither
}

public enum AuthSource: String, Sendable {
  case environment
  case secretsManager
  case identityProvider
}

public struct AuthCredentials: Equatable, Sendable {
  public let provider: AuthProvider
  public let tokenType: TokenType
  public let audience: AuthAudience
  public let issuedAt: Date?
  public let expiresAt: Date?
  public let source: AuthSource

  public init(
    provider: AuthProvider,
    tokenType: TokenType,
    audience: AuthAudience,
    issuedAt: Date?,
    expiresAt: Date?,
    source: AuthSource
  ) throws {
    if provider == .service, audience == .gaia {
      throw AuthenticationError.invalidServiceAudience
    }

    self.provider = provider
    self.tokenType = tokenType
    self.audience = audience
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.source = source
  }
}

public struct AuthorizationRule: Equatable, Sendable {
  public let resource: String
  public let action: String
  public let allowedRoles: [String]
  public let requiresActiveSession: Bool
  public let requiresServiceAudience: DownstreamService?

  public init(
    resource: String,
    action: String,
    allowedRoles: [String],
    requiresActiveSession: Bool,
    requiresServiceAudience: DownstreamService?
  ) throws {
    if requiresActiveSession && allowedRoles.isEmpty {
      throw AuthenticationError.emptyAllowedRoles
    }

    let isDownstreamControlled = resource.hasPrefix("service/") || action.hasPrefix("service:")
    if isDownstreamControlled, requiresServiceAudience == nil {
      throw AuthenticationError.missingServiceAudience
    }

    self.resource = resource
    self.action = action
    self.allowedRoles = allowedRoles
    self.requiresActiveSession = requiresActiveSession
    self.requiresServiceAudience = requiresServiceAudience
  }
}
