import Foundation

public struct InteractiveAuthenticationRequest: Equatable, Sendable {
  public let returnToPath: String
  public let requestId: String

  public init(returnToPath: String, requestId: String) {
    self.returnToPath = returnToPath
    self.requestId = requestId
  }
}

public struct InteractiveAuthenticationChallenge: Equatable, Sendable {
  public let status: String
  public let nextURL: URL

  public init(status: String, nextURL: URL) {
    self.status = status
    self.nextURL = nextURL
  }
}

public protocol InteractiveAuthenticationProviding: Sendable {
  func beginAuthentication(
    request: InteractiveAuthenticationRequest
  ) async throws -> InteractiveAuthenticationChallenge
}

public struct StaticInteractiveAuthenticationProvider: InteractiveAuthenticationProviding {
  public let authenticationBaseURL: URL

  public init(authenticationBaseURL: URL) {
    self.authenticationBaseURL = authenticationBaseURL
  }

  public func beginAuthentication(
    request: InteractiveAuthenticationRequest
  ) async throws -> InteractiveAuthenticationChallenge {
    guard UserSession.isSafeInternalPath(request.returnToPath) else {
      throw AuthenticationError.invalidReturnPath
    }

    var components = URLComponents(
      url: authenticationBaseURL.appendingPathComponent("authentication"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
      URLQueryItem(name: "returnTo", value: request.returnToPath),
      URLQueryItem(name: "requestId", value: request.requestId),
    ]

    guard let nextURL = components?.url else {
      throw AuthenticationError.unsafeFailure(reason: "challenge_url_unavailable")
    }

    return InteractiveAuthenticationChallenge(status: "challenge", nextURL: nextURL)
  }
}
