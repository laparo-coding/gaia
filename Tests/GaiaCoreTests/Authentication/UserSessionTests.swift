import Testing

@testable import GaiaCore

struct UserSessionTests {
  @Test
  func authenticatedSessionRequiresSubjectIdAndSafeReturnPath() throws {
    let session = try UserSession(
      sessionId: AuthTestSupport.sessionId,
      subjectId: AuthTestSupport.subjectId,
      role: AuthTestSupport.role,
      status: .authenticated,
      issuedAt: AuthTestSupport.issuedAt,
      expiresAt: AuthTestSupport.expiresAt,
      returnToPath: AuthTestSupport.validReturnPath
    )

    #expect(session.subjectId == AuthTestSupport.subjectId)
    #expect(session.isActive(at: AuthTestSupport.issuedAt))
  }

  @Test
  func authenticatedSessionRejectsMissingSubjectOrUnsafeReturnPath() {
    #expect(throws: AuthenticationError.self) {
      _ = try UserSession(
        sessionId: AuthTestSupport.sessionId,
        subjectId: nil,
        role: AuthTestSupport.role,
        status: .authenticated,
        issuedAt: AuthTestSupport.issuedAt,
        expiresAt: AuthTestSupport.expiresAt,
        returnToPath: AuthTestSupport.validReturnPath
      )
    }

    #expect(throws: AuthenticationError.self) {
      _ = try UserSession(
        sessionId: AuthTestSupport.sessionId,
        subjectId: AuthTestSupport.subjectId,
        role: AuthTestSupport.role,
        status: .authenticated,
        issuedAt: AuthTestSupport.issuedAt,
        expiresAt: AuthTestSupport.expiresAt,
        returnToPath: AuthTestSupport.invalidReturnPath
      )
    }
  }

  @Test
  func sessionTransitionsToExpiredAndSignedOut() throws {
    let session = try UserSession(
      sessionId: AuthTestSupport.sessionId,
      subjectId: AuthTestSupport.subjectId,
      role: AuthTestSupport.role,
      status: .authenticated,
      issuedAt: AuthTestSupport.issuedAt,
      expiresAt: AuthTestSupport.expiresAt,
      returnToPath: AuthTestSupport.validReturnPath
    )

    let expired = try session.transitioning(to: .expired)
    let signedOut = try session.transitioning(to: .signedOut)

    #expect(expired.status == .expired)
    #expect(signedOut.status == .signedOut)
  }
}
