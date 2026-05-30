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

enum SessionRouteBody: Encodable {
  case session(SessionStatePayload)
  case error(AuthenticationErrorPayload)

  func encode(to encoder: Encoder) throws {
    switch self {
    case .session(let payload):
      try payload.encode(to: encoder)
    case .error(let payload):
      try payload.encode(to: encoder)
    }
  }
}

enum SessionRouteHandler {
  static let path = "/api/auth/session"
  static let supportedMethods = ["GET", "DELETE"]

  static func get(
    runtime: AuthenticationRuntime,
    requestId: String
  ) async -> AuthenticationRouteResponse<SessionRouteBody> {
    let state = await runtime.readSession()
    let status = state.status.rawValue

    guard status != "unauthenticated", status != "signedOut", status != "failed" else {
      return AuthenticationRouteResponse(
        statusCode: 401,
        body: .error(
          AuthenticationErrorPayload(
            error: "no_active_session",
            message: "No active session exists.",
            requestId: requestId
          ))
      )
    }

    return AuthenticationRouteResponse(
      statusCode: 200,
      body: .session(
        SessionStatePayload(
          status: status,
          subjectId: state.subjectId,
          role: state.role,
          expiresAt: state.expiresAt,
          returnToPath: state.returnToPath
        ))
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
