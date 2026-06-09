import Foundation

public struct SeminarStartPolicy: Sendable {
  public let requiredRole: String

  public init(requiredRole: String = "moderator") {
    self.requiredRole = requiredRole
  }

  public func canStartSeminar(session: RuntimeSessionState) -> Bool {
    guard session.status == .authenticated else {
      return false
    }

    return session.role == requiredRole
  }
}
