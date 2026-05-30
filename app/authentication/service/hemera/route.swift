import Foundation
import GaiaCore

struct ServiceAuthorizationRequestPayload: Codable, Equatable, Sendable {
  let operation: String
  let requestId: String?
}

struct ServiceAuthorizationResponsePayload: Codable, Equatable, Sendable {
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
      requestId: request.requestId ?? UUID().uuidString,
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
        service: DownstreamService.hemera.rawValue,
        status: authorization.status.rawValue,
        retryOnExpiry: authorization.retryOnExpiry,
        expiresAt: authorization.expiresAt
      )
    )
  }
}
