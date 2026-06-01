import Foundation

public enum AuthenticationError: Error, Equatable, Sendable {
  case missingSubjectId
  case invalidSessionWindow
  case invalidReturnPath
  case invalidTransition(from: UserSessionStatus, to: UserSessionStatus)
  case invalidServiceAudience
  case emptyAllowedRoles
  case missingServiceAudience
  case missingEnvironmentKey
  case invalidRefreshLeeway
  case serviceAuthorizationFailed(service: DownstreamService)
  case downstreamAuthenticationExpired(service: DownstreamService, signal: String)
  case unsafeFailure(reason: String)
}

public enum UserSessionStatus: String, Sendable {
  case unauthenticated
  case authenticating
  case authenticated
  case expired
  case signedOut
  case failed
}

public struct UserSession: Equatable, Sendable {
  public let sessionId: String?
  public let subjectId: String?
  public let role: String?
  public let status: UserSessionStatus
  public let issuedAt: Date?
  public let expiresAt: Date?
  public let returnToPath: String?

  public init(
    sessionId: String?,
    subjectId: String?,
    role: String?,
    status: UserSessionStatus,
    issuedAt: Date?,
    expiresAt: Date?,
    returnToPath: String?
  ) throws {
    if status == .authenticated, subjectId?.isEmpty != false {
      throw AuthenticationError.missingSubjectId
    }

    if let issuedAt, let expiresAt, expiresAt <= issuedAt {
      throw AuthenticationError.invalidSessionWindow
    }

    if let returnToPath, !Self.isSafeInternalPath(returnToPath) {
      throw AuthenticationError.invalidReturnPath
    }

    self.sessionId = sessionId
    self.subjectId = subjectId
    self.role = role
    self.status = status
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.returnToPath = returnToPath
  }

  init(
    uncheckedSessionId sessionId: String?,
    subjectId: String?,
    role: String?,
    status: UserSessionStatus,
    issuedAt: Date?,
    expiresAt: Date?,
    returnToPath: String?
  ) {
    self.sessionId = sessionId
    self.subjectId = subjectId
    self.role = role
    self.status = status
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.returnToPath = returnToPath
  }

  public static let unauthenticated = UserSession(
    uncheckedSessionId: nil,
    subjectId: nil,
    role: nil,
    status: .unauthenticated,
    issuedAt: nil,
    expiresAt: nil,
    returnToPath: nil
  )

  public func isActive(at date: Date) -> Bool {
    guard status == .authenticated else {
      return false
    }

    guard let expiresAt else {
      return false
    }

    return expiresAt > date
  }

  public func transitioning(to status: UserSessionStatus) throws -> UserSession {
    let allowedTransitions: [UserSessionStatus: Set<UserSessionStatus>] = [
      .unauthenticated: [.authenticating],
      .authenticating: [.authenticated, .failed],
      .authenticated: [.expired, .signedOut],
      .expired: [.authenticating, .signedOut],
      .signedOut: [.authenticating],
      .failed: [.authenticating, .signedOut],
    ]

    guard allowedTransitions[self.status, default: []].contains(status) else {
      throw AuthenticationError.invalidTransition(from: self.status, to: status)
    }

    return try UserSession(
      sessionId: sessionId,
      subjectId: status == .authenticated ? subjectId : nil,
      role: status == .authenticated ? role : nil,
      status: status,
      issuedAt: issuedAt,
      expiresAt: status == .authenticated ? expiresAt : nil,
      returnToPath: returnToPath
    )
  }

  static func isSafeInternalPath(_ path: String) -> Bool {
    path.hasPrefix("/") && !path.hasPrefix("//") && !path.contains("://")
  }
}
