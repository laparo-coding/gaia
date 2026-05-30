import Foundation

public struct AuthenticationLogEntry: Equatable, Sendable {
  public let service: DownstreamService
  public let requestId: String
  public let message: String

  public init(service: DownstreamService, requestId: String, message: String) {
    self.service = service
    self.requestId = requestId
    self.message = message
  }
}

public actor AuthenticationTelemetry {
  private var entries: [AuthenticationLogEntry] = []

  public init() {}

  public func safeUserMessage(for error: AuthenticationError) -> String {
    switch error {
    case .downstreamAuthenticationExpired:
      return "Authentication expired. Retry the request."
    case .serviceAuthorizationFailed:
      return "Service authentication is temporarily unavailable."
    default:
      return "Authentication failed. Try again."
    }
  }

  public func recordFailure(
    service: DownstreamService,
    requestId: String,
    error: AuthenticationError
  ) {
    let message = safeLogMessage(for: error)
    entries.append(AuthenticationLogEntry(service: service, requestId: requestId, message: message))
  }

  public func entriesSnapshot() -> [AuthenticationLogEntry] {
    entries
  }

  private func safeLogMessage(for error: AuthenticationError) -> String {
    switch error {
    case .unsafeFailure:
      return "Authentication failure recorded without sensitive detail."
    case .downstreamAuthenticationExpired(let service, let signal):
      return "Downstream authentication expired for \(service.rawValue) with signal \(signal)."
    case .serviceAuthorizationFailed(let service):
      return "Service authorization failed for \(service.rawValue)."
    default:
      return "Authentication error (details redacted)."
    }
  }
}
