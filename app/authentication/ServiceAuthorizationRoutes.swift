import Foundation
import GaiaCore

struct ServiceAuthorizationRequestPayload: Codable, Equatable {
  let operation: String
  let requestId: String?
}

struct ServiceAuthorizationResponsePayload: Codable, Equatable {
  let service: String
  let status: String
  let retryOnExpiry: Bool
  let expiresAt: Date?
}

enum HemeraServiceAuthorizationRoute {
  static let path = "/api/auth/service/hemera/authorize"
  static let supportedMethods = ["POST"]

  static func post(
    runtime: AuthenticationRuntime,
    _ request: ServiceAuthorizationRequestPayload,
    now: Date
  ) async -> AuthenticationRouteResponse<ServiceAuthorizationResponsePayload> {
    let authorization = await runtime.authorizeService(
      service: .hemera,
      operation: request.operation,
      requestId: request.requestId ?? "hemera-auth-request",
      now: now
    )
    let statusCode = authorization.status == .degraded ? 502 : 200

    return AuthenticationRouteResponse(
      statusCode: statusCode,
      body: ServiceAuthorizationResponsePayload(
        service: "hemera",
        status: authorization.status.rawValue,
        retryOnExpiry: authorization.retryOnExpiry,
        expiresAt: authorization.expiresAt
      )
    )
  }
}

enum AitherServiceAuthorizationRoute {
  static let path = "/api/auth/service/aither/authorize"
  static let supportedMethods = ["POST"]

  static func post(
    runtime: AuthenticationRuntime,
    _ request: ServiceAuthorizationRequestPayload,
    now: Date
  ) async -> AuthenticationRouteResponse<ServiceAuthorizationResponsePayload> {
    let authorization = await runtime.authorizeService(
      service: .aither,
      operation: request.operation,
      requestId: request.requestId ?? "aither-auth-request",
      now: now
    )
    let statusCode = authorization.status == .degraded ? 502 : 200

    return AuthenticationRouteResponse(
      statusCode: statusCode,
      body: ServiceAuthorizationResponsePayload(
        service: "aither",
        status: authorization.status.rawValue,
        retryOnExpiry: authorization.retryOnExpiry,
        expiresAt: authorization.expiresAt
      )
    )
  }
}
