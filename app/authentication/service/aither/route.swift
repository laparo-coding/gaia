import Foundation
import GaiaCore

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

    let statusCode: Int
    switch authorization.status {
    case .authorized, .refreshed:
      statusCode = 200
    case .degraded:
      statusCode = 502
    }

    return AuthenticationRouteResponse(
      statusCode: statusCode,
      body: ServiceAuthorizationResponsePayload(
        service: DownstreamService.aither.rawValue,
        status: authorization.status.rawValue,
        retryOnExpiry: authorization.retryOnExpiry,
        expiresAt: authorization.expiresAt
      )
    )
  }
}
