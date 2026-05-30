import Foundation

public actor AuthenticationSessionManager {
  private var session: UserSession

  public init(session: UserSession = .unauthenticated) {
    self.session = session
  }

  public func currentSession() -> UserSession {
    session
  }

  public func startSignIn(returnToPath: String?) throws -> UserSession {
    session = try UserSession(
      sessionId: nil,
      subjectId: nil,
      role: nil,
      status: .authenticating,
      issuedAt: nil,
      expiresAt: nil,
      returnToPath: returnToPath
    )
    return session
  }

  public func completeSignIn(
    sessionId: String,
    subjectId: String,
    role: String,
    issuedAt: Date,
    expiresAt: Date
  ) throws -> UserSession {
    session = try UserSession(
      sessionId: sessionId,
      subjectId: subjectId,
      role: role,
      status: .authenticated,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      returnToPath: session.returnToPath
    )
    return session
  }

  public func failSignIn() -> UserSession {
    session = UserSession(
      uncheckedSessionId: nil,
      subjectId: nil,
      role: nil,
      status: .failed,
      issuedAt: nil,
      expiresAt: nil,
      returnToPath: session.returnToPath
    )
    return session
  }

  public func expireSession() -> UserSession {
    session = UserSession(
      uncheckedSessionId: session.sessionId,
      subjectId: nil,
      role: nil,
      status: .expired,
      issuedAt: session.issuedAt,
      expiresAt: nil,
      returnToPath: session.returnToPath
    )
    return session
  }

  public func signOut() -> UserSession {
    session = UserSession(
      uncheckedSessionId: nil,
      subjectId: nil,
      role: nil,
      status: .signedOut,
      issuedAt: nil,
      expiresAt: nil,
      returnToPath: nil
    )
    return session
  }

  public func authorize(_ rule: AuthorizationRule, activeService: DownstreamService?) -> Bool {
    if rule.requiresActiveSession {
      guard session.isActive(at: Date()) else {
        return false
      }

      guard let role = session.role, rule.allowedRoles.contains(role) else {
        return false
      }
    }

    if let requiredService = rule.requiresServiceAudience {
      return requiredService == activeService
    }

    return true
  }
}
