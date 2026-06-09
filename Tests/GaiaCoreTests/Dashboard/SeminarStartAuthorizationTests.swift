import Foundation
import Testing

@testable import GaiaCore

struct SeminarStartAuthorizationTests {
  @Test
  func moderatorCanStartSeminar() throws {
    let policy = SeminarStartPolicy(requiredRole: "moderator")
    let state = RuntimeSessionState(
      session: try UserSession(
        sessionId: "session-1",
        subjectId: "user-1",
        role: "moderator",
        status: .authenticated,
        issuedAt: Date(),
        expiresAt: Date().addingTimeInterval(3600),
        returnToPath: nil
      )
    )

    #expect(policy.canStartSeminar(session: state))
  }

  @Test
  func authenticatedWithoutModeratorRoleCannotStartSeminar() throws {
    let policy = SeminarStartPolicy(requiredRole: "moderator")
    let state = RuntimeSessionState(
      session: try UserSession(
        sessionId: "session-2",
        subjectId: "user-2",
        role: "viewer",
        status: .authenticated,
        issuedAt: Date(),
        expiresAt: Date().addingTimeInterval(3600),
        returnToPath: nil
      )
    )

    #expect(!policy.canStartSeminar(session: state))
  }

  @Test
  func unauthenticatedSessionCannotStartSeminar() throws {
    let policy = SeminarStartPolicy(requiredRole: "moderator")
    let state = RuntimeSessionState(
      session: try UserSession(
        sessionId: nil,
        subjectId: nil,
        role: "moderator",
        status: .unauthenticated,
        issuedAt: Date(),
        expiresAt: Date().addingTimeInterval(3600),
        returnToPath: nil
      )
    )

    #expect(!policy.canStartSeminar(session: state))
  }
}
