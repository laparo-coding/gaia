import Testing

@testable import GaiaCore

struct InteractiveSignInScenarioTests {
  @Test
  func signInRestoresProtectedDestination() async throws {
    let manager = AuthenticationSessionManager()

    let authenticating = try await manager.startSignIn(
      returnToPath: AuthTestSupport.validReturnPath)
    let authenticated = try await manager.completeSignIn(
      sessionId: AuthTestSupport.sessionId,
      subjectId: AuthTestSupport.subjectId,
      role: AuthTestSupport.role,
      issuedAt: AuthTestSupport.issuedAt,
      expiresAt: AuthTestSupport.expiresAt
    )

    #expect(authenticating.status == .authenticating)
    #expect(authenticated.status == .authenticated)
    #expect(authenticated.returnToPath == AuthTestSupport.validReturnPath)
  }
}
