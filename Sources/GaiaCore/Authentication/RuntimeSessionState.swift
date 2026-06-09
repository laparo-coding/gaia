import Foundation

public struct RuntimeSessionState: Equatable, Sendable {
  public let status: UserSessionStatus
  public let subjectId: String?
  public let role: String?
  public let expiresAt: Date?
  public let returnToPath: String?

  public init(session: UserSession) {
    status = session.status
    subjectId = session.subjectId
    role = session.role
    expiresAt = session.expiresAt
    returnToPath = session.returnToPath
  }
}
