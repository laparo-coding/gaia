import Foundation

public enum ControllerTelemetryEvent: String, Sendable {
  case manifestLoadFailed
  case navigationFailed
  case slideHTMLFetchFailed
  case bridgeOutOfSync
}

public struct ControllerTelemetryEntry: Equatable, Sendable {
  public let event: ControllerTelemetryEvent
  public let requestID: String
  public let message: String

  public init(event: ControllerTelemetryEvent, requestID: String, message: String) {
    self.event = event
    self.requestID = requestID
    self.message = message
  }
}

public actor ControllerTelemetry {
  private static let maxEntries = 200
  private var entries: [ControllerTelemetryEntry] = []

  public init() {}

  public func safeUserMessage(for error: AuthenticationError) -> String {
    switch error {
    case .downstreamAuthenticationExpired:
      return "The session expired. Retry navigation."
    case .serviceAuthorizationFailed:
      return "Slide service is temporarily unavailable."
    default:
      return "Controller request failed. Try again."
    }
  }

  public func recordFailure(
    event: ControllerTelemetryEvent,
    requestID: String,
    error: AuthenticationError
  ) {
    let message = safeLogMessage(for: error)
    entries.append(ControllerTelemetryEntry(event: event, requestID: requestID, message: message))
    if entries.count > Self.maxEntries {
      entries.removeFirst(entries.count - Self.maxEntries)
    }
  }

  public func entriesSnapshot() -> [ControllerTelemetryEntry] {
    entries
  }

  private func safeLogMessage(for error: AuthenticationError) -> String {
    switch error {
    case .downstreamAuthenticationExpired(let service, let signal):
      return "Controller downstream auth expired for \(service.rawValue) with signal \(signal)."
    case .serviceAuthorizationFailed(let service):
      return "Controller service authorization failed for \(service.rawValue)."
    default:
      return "Controller error recorded (details redacted)."
    }
  }
}
