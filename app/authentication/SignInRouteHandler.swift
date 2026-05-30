import GaiaCore

struct SignInRequestPayload: Codable, Equatable {
  let returnToPath: String
}

struct SignInResponsePayload: Codable, Equatable {
  let status: String
  let nextUrl: String
}

enum SignInRouteHandler {
  static let path = "/api/auth/sign-in"
  static let supportedMethods = ["POST"]

  static func post(
    runtime: AuthenticationRuntime,
    _ request: SignInRequestPayload,
    requestId: String
  ) async -> AuthenticationRouteResponse<SignInResponsePayload> {
    do {
      let challenge = try await runtime.beginSignIn(
        returnToPath: request.returnToPath,
        requestId: requestId
      )

      return AuthenticationRouteResponse(
        statusCode: 200,
        body: SignInResponsePayload(
          status: challenge.status,
          nextUrl: challenge.nextURL.absoluteString
        )
      )
    } catch {
      return AuthenticationRouteResponse(statusCode: 400, body: nil)
    }
  }
}
