import Foundation
import GaiaCore

struct AuthenticationRouteResponse<Body> {
  let statusCode: Int
  let body: Body?
}

struct AuthenticationErrorPayload: Codable, Equatable {
  let error: String
  let message: String
  let requestId: String?
}

struct SessionStatePayload: Codable, Equatable {
  let status: String
  let subjectId: String?
  let role: String?
  let expiresAt: Date?
  let returnToPath: String?
}

enum SessionRouteHandler {
  static let path = "/api/auth/session"
  static let supportedMethods = ["GET", "DELETE"]

  static func get(
    runtime: AuthenticationRuntime,
    requestId _: String
  ) async -> AuthenticationRouteResponse<SessionStatePayload> {
    let state = await runtime.readSession()
    let status = state.status.rawValue

    guard status != "unauthenticated", status != "signedOut", status != "failed" else {
      return AuthenticationRouteResponse(statusCode: 401, body: nil)
    }

    return AuthenticationRouteResponse(
      statusCode: 200,
      body: SessionStatePayload(
        status: status,
        subjectId: state.subjectId,
        role: state.role,
        expiresAt: state.expiresAt,
        returnToPath: state.returnToPath
      )
    )
  }

  static func delete(
    runtime: AuthenticationRuntime,
    requestId: String
  ) async -> AuthenticationRouteResponse<AuthenticationErrorPayload> {
    let state = await runtime.readSession()

    if state.status == .authenticated {
      _ = await runtime.signOut()
      return AuthenticationRouteResponse(statusCode: 204, body: nil)
    }

    return AuthenticationRouteResponse(
      statusCode: 401,
      body: AuthenticationErrorPayload(
        error: "no_active_session",
        message: "No active session exists.",
        requestId: requestId
      )
    )
  }
}
