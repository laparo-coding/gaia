import GaiaCore

enum AuthenticationPageState: Equatable {
  case signIn(title: String, message: String, returnToPath: String?)
  case authenticating(title: String, message: String)
  case authenticated(title: String, summary: String)
  case failed(title: String, message: String, retryActionLabel: String)
  case degraded(title: String, message: String, retryActionLabel: String)
}

enum AuthenticationPage {
  static let path = "/authentication"

  static func state(for session: RuntimeSessionState) -> AuthenticationPageState {
    switch session.status {
    case .authenticating:
      return .authenticating(
        title: "Signing you in",
        message: "Gaia is completing the interactive authentication flow."
      )
    case .authenticated:
      return .authenticated(
        title: "Access granted",
        summary: "Protected content is available and your destination can be restored."
      )
    case .failed:
      return .failed(
        title: "Authentication failed",
        message: "Sign in again or return to a safe public area.",
        retryActionLabel: "Retry sign-in"
      )
    case .expired:
      return .degraded(
        title: "Limited availability",
        message: "Your session expired. Sign in again to continue.",
        retryActionLabel: "Sign in again"
      )
    default:
      return .signIn(
        title: "Sign in required",
        message: "Authenticate before protected content is shown.",
        returnToPath: session.returnToPath
      )
    }
  }
}
