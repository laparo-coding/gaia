import Foundation
import GaiaCore
import Network

private let environment = LocalEnvironment.mergedWithProcessEnvironment(
  currentDirectoryPath: FileManager.default.currentDirectoryPath,
  processEnvironment: ProcessInfo.processInfo.environment
)
private let _ = RollbarBootstrap.initialize(
  environment: environment,
  appName: "GaiaAuthenticationApp"
)
private let configuration = try AuthenticationAppConfiguration(
  arguments: Array(CommandLine.arguments.dropFirst()),
  environment: environment
)
private let runtime = try configuration.makeRuntime()
private let server = try AuthenticationHTTPServer(configuration: configuration, runtime: runtime)

try server.start()

private struct AuthenticationAppConfiguration {
  let host: String
  let port: UInt16
  let baseURL: URL
  let hemeraToken: String?
  let aitherToken: String?

  init(arguments: [String], environment: [String: String]) throws {
    let portArgumentIndex = arguments.firstIndex(of: "--port")
    let hostArgumentIndex = arguments.firstIndex(of: "--host")

    if let portArgumentIndex, arguments.indices.contains(portArgumentIndex + 1) {
      guard let parsedPort = UInt16(arguments[portArgumentIndex + 1]) else {
        throw AuthenticationError.unsafeFailure(reason: "invalid_port")
      }
      port = parsedPort
    } else {
      port = 8080
    }

    if let hostArgumentIndex, arguments.indices.contains(hostArgumentIndex + 1) {
      host = arguments[hostArgumentIndex + 1]
    } else {
      host = "127.0.0.1"
    }

    if let baseURLString = environment["GAIA_AUTH_BASE_URL"],
      let baseURL = URL(string: baseURLString)
    {
      self.baseURL = baseURL
    } else {
      guard let baseURL = URL(string: "http://\(host):\(port)") else {
        throw AuthenticationError.unsafeFailure(reason: "invalid_base_url")
      }
      self.baseURL = baseURL
    }

    hemeraToken = environment["HEMERA_SERVICE_API_KEY"] ?? environment["HEMERA_SERVICE_TOKEN"]
    aitherToken = environment["AITHER_SYNC_TOKEN"] ?? environment["AITHER_SERVICE_TOKEN"]
  }

  func makeRuntime() throws -> AuthenticationRuntime {
    let cacheStore = ServiceTokenCacheStore()
    let telemetry = AuthenticationTelemetry()
    let sessionManager = AuthenticationSessionManager()
    let interactiveProvider = StaticInteractiveAuthenticationProvider(
      authenticationBaseURL: baseURL)

    let hemeraCredential = try ServiceCredential(
      service: .hemera,
      envPrimaryKey: "HEMERA_SERVICE_API_KEY",
      envFallbackKey: "HEMERA_SERVICE_TOKEN",
      cacheKey: "service.hemera",
      tokenType: .bearer,
      audience: "hemera",
      refreshLeewaySeconds: 60
    )
    let aitherCredential = try ServiceCredential(
      service: .aither,
      envPrimaryKey: "AITHER_SYNC_TOKEN",
      envFallbackKey: "AITHER_SERVICE_TOKEN",
      cacheKey: "service.aither",
      tokenType: .bearer,
      audience: "aither",
      refreshLeewaySeconds: 60
    )

    let hemeraAuthenticator = HemeraServiceAuthenticator(
      credential: hemeraCredential,
      cacheStore: cacheStore,
      tokenProvider: makeTokenProvider(service: .hemera, configuredToken: hemeraToken)
    )
    let aitherAuthenticator = AitherServiceAuthenticator(
      credential: aitherCredential,
      cacheStore: cacheStore,
      tokenProvider: makeTokenProvider(service: .aither, configuredToken: aitherToken)
    )

    let coordinator = ServiceAuthorizationCoordinator(
      cacheStore: cacheStore,
      hemeraAuthenticator: hemeraAuthenticator,
      aitherAuthenticator: aitherAuthenticator,
      telemetry: telemetry
    )

    return AuthenticationRuntime(
      sessionManager: sessionManager,
      interactiveProvider: interactiveProvider,
      serviceCoordinator: coordinator
    )
  }

  private func makeTokenProvider(
    service: DownstreamService,
    configuredToken: String?
  ) -> @Sendable (ServiceCredential) throws -> LoadedServiceToken {
    { _ in
      guard let configuredToken, !configuredToken.isEmpty else {
        throw AuthenticationError.serviceAuthorizationFailed(service: service)
      }

      let now = Date()
      return LoadedServiceToken(
        token: configuredToken,
        expiresAt: now.addingTimeInterval(3600),
        refreshedAt: now
      )
    }
  }
}

private final class AuthenticationHTTPServer: @unchecked Sendable {
  private static let maxRequestBufferBytes = 1_048_576

  private let configuration: AuthenticationAppConfiguration
  private let runtime: AuthenticationRuntime
  private let listener: NWListener
  private let queue = DispatchQueue(label: "gaia.authentication.http")
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(configuration: AuthenticationAppConfiguration, runtime: AuthenticationRuntime) throws {
    self.configuration = configuration
    self.runtime = runtime
    guard let nwPort = NWEndpoint.Port(rawValue: configuration.port) else {
      throw AuthenticationError.unsafeFailure(reason: "invalid_listener_port")
    }
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = .hostPort(
      host: NWEndpoint.Host(configuration.host),
      port: nwPort
    )
    listener = try NWListener(using: parameters)
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
  }

  func start() throws {
    listener.stateUpdateHandler = { state in
      if case .failed(let error) = state {
        fputs("GaiaAuthenticationApp listener failed: \(error)\n", stderr)
      }
    }

    listener.newConnectionHandler = { [weak self] connection in
      self?.handle(connection: connection)
    }
    listener.start(queue: queue)

    print("GaiaAuthenticationApp listening on \(configuration.baseURL.absoluteString)")
    dispatchMain()
  }

  private func handle(connection: NWConnection) {
    connection.start(queue: queue)
    receive(on: connection, buffer: Data())
  }

  private func receive(on connection: NWConnection, buffer: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
      [weak self] data, _, _, error in
      guard let self else {
        connection.cancel()
        return
      }

      if let error {
        fputs("Receive error: \(error)\n", stderr)
        connection.cancel()
        return
      }

      var updatedBuffer = buffer
      if let data {
        updatedBuffer.append(data)
      }

      if updatedBuffer.count > Self.maxRequestBufferBytes {
        fputs(
          "Request buffer exceeded \(Self.maxRequestBufferBytes) bytes; closing connection.\n",
          stderr
        )
        connection.cancel()
        return
      }

      guard let request = self.parseRequest(from: updatedBuffer) else {
        self.receive(on: connection, buffer: updatedBuffer)
        return
      }

      Task {
        let response = await self.makeResponse(for: request)
        connection.send(
          content: response,
          completion: .contentProcessed { _ in
            connection.cancel()
          })
      }
    }
  }

  private func makeResponse(for request: HTTPRequest) async -> Data {
    let requestId = request.headers["x-request-id"] ?? UUID().uuidString

    switch (request.method, request.path) {
    case ("GET", AuthenticationPage.path):
      let session = await runtime.readSession()
      return makeHTMLResponse(statusCode: 200, body: renderPage(for: session))

    case ("GET", SessionRouteHandler.path):
      let response = await SessionRouteHandler.get(runtime: runtime, requestId: requestId)
      return makeJSONResponse(statusCode: response.statusCode, body: response.body)

    case ("DELETE", SessionRouteHandler.path):
      let response = await SessionRouteHandler.delete(runtime: runtime, requestId: requestId)
      return makeJSONResponse(statusCode: response.statusCode, body: response.body)

    case ("POST", SignInRouteHandler.path):
      guard let payload = try? decoder.decode(SignInRequestPayload.self, from: request.body) else {
        return makeJSONResponse(
          statusCode: 400,
          body: AuthenticationErrorPayload(
            error: "invalid_request",
            message: "Sign-in payload could not be decoded.",
            requestId: requestId
          )
        )
      }
      let response = await SignInRouteHandler.post(runtime: runtime, payload, requestId: requestId)
      return makeJSONResponse(statusCode: response.statusCode, body: response.body)

    case ("POST", HemeraServiceAuthorizationRoute.path):
      guard
        let payload = try? decoder.decode(
          ServiceAuthorizationRequestPayload.self, from: request.body)
      else {
        return makeJSONResponse(
          statusCode: 400,
          body: AuthenticationErrorPayload(
            error: "invalid_request",
            message: "Hemera authorization payload could not be decoded.",
            requestId: requestId
          )
        )
      }
      let response = await HemeraServiceAuthorizationRoute.post(
        runtime: runtime,
        payload,
        now: Date()
      )
      return makeJSONResponse(statusCode: response.statusCode, body: response.body)

    case ("POST", AitherServiceAuthorizationRoute.path):
      guard
        let payload = try? decoder.decode(
          ServiceAuthorizationRequestPayload.self, from: request.body)
      else {
        return makeJSONResponse(
          statusCode: 400,
          body: AuthenticationErrorPayload(
            error: "invalid_request",
            message: "Aither authorization payload could not be decoded.",
            requestId: requestId
          )
        )
      }
      let response = await AitherServiceAuthorizationRoute.post(
        runtime: runtime,
        payload,
        now: Date()
      )
      return makeJSONResponse(statusCode: response.statusCode, body: response.body)

    default:
      return makeJSONResponse(
        statusCode: 404,
        body: AuthenticationErrorPayload(
          error: "not_found",
          message: "No authentication route matches the request.",
          requestId: requestId
        )
      )
    }
  }

  private func makeJSONResponse<Body: Encodable>(statusCode: Int, body: Body?) -> Data {
    let payload = (try? body.map { try encoder.encode($0) }) ?? nil
    return makeHTTPResponse(
      statusCode: statusCode,
      contentType: "application/json; charset=utf-8",
      body: payload ?? Data()
    )
  }

  private func makeHTMLResponse(statusCode: Int, body: String) -> Data {
    makeHTTPResponse(
      statusCode: statusCode,
      contentType: "text/html; charset=utf-8",
      body: Data(body.utf8)
    )
  }

  private func makeHTTPResponse(statusCode: Int, contentType: String, body: Data) -> Data {
    let statusText: String
    switch statusCode {
    case 200: statusText = "OK"
    case 204: statusText = "No Content"
    case 400: statusText = "Bad Request"
    case 401: statusText = "Unauthorized"
    case 404: statusText = "Not Found"
    case 502: statusText = "Bad Gateway"
    default: statusText = "Internal Server Error"
    }

    var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
    response += "Content-Type: \(contentType)\r\n"
    response += "Content-Length: \(body.count)\r\n"
    response += "Connection: close\r\n\r\n"

    var data = Data(response.utf8)
    data.append(body)
    return data
  }

  private func parseRequest(from data: Data) -> HTTPRequest? {
    let separator = Data("\r\n\r\n".utf8)
    guard let headerRange = data.range(of: separator) else {
      return nil
    }

    let headerData = data[..<headerRange.lowerBound]
    guard let headerString = String(data: headerData, encoding: .utf8) else {
      return nil
    }

    let headerLines = headerString.components(separatedBy: "\r\n")
    guard let requestLine = headerLines.first else {
      return nil
    }

    let requestParts = requestLine.split(separator: " ")
    guard requestParts.count >= 2 else {
      return nil
    }

    var headers: [String: String] = [:]
    for line in headerLines.dropFirst() {
      let pieces = line.split(separator: ":", maxSplits: 1).map(String.init)
      if pieces.count == 2 {
        headers[pieces[0].lowercased()] = pieces[1].trimmingCharacters(in: .whitespaces)
      }
    }

    let bodyStart = headerRange.upperBound
    let contentLength = Int(headers["content-length"] ?? "0") ?? 0
    guard contentLength >= 0 else {
      return nil
    }

    let end = bodyStart + contentLength
    guard end >= bodyStart, end <= data.count else {
      return nil
    }

    let body = Data(data[bodyStart..<end])
    return HTTPRequest(
      method: String(requestParts[0]),
      path: String(requestParts[1]),
      headers: headers,
      body: body
    )
  }

  private func renderPage(for session: RuntimeSessionState) -> String {
    let state = AuthenticationPage.state(for: session)

    switch state {
    case .signIn(let title, let message, let returnToPath):
      let safeTitle = escapeHTML(title)
      let safeMessage = escapeHTML(message)
      let safeReturnToPath = escapeHTML(returnToPath ?? "/")
      return htmlDocument(
        title: safeTitle,
        body: "<h1>\(safeTitle)</h1><p>\(safeMessage)</p><p>Return to: \(safeReturnToPath)</p>"
      )
    case .authenticating(let title, let message):
      let safeTitle = escapeHTML(title)
      let safeMessage = escapeHTML(message)
      return htmlDocument(title: safeTitle, body: "<h1>\(safeTitle)</h1><p>\(safeMessage)</p>")
    case .authenticated(let title, let summary):
      let safeTitle = escapeHTML(title)
      let safeSummary = escapeHTML(summary)
      return htmlDocument(title: safeTitle, body: "<h1>\(safeTitle)</h1><p>\(safeSummary)</p>")
    case .failed(let title, let message, let retryActionLabel):
      let safeTitle = escapeHTML(title)
      let safeMessage = escapeHTML(message)
      let safeRetryActionLabel = escapeHTML(retryActionLabel)
      return htmlDocument(
        title: safeTitle,
        body: "<h1>\(safeTitle)</h1><p>\(safeMessage)</p><button>\(safeRetryActionLabel)</button>"
      )
    case .degraded(let title, let message, let retryActionLabel):
      let safeTitle = escapeHTML(title)
      let safeMessage = escapeHTML(message)
      let safeRetryActionLabel = escapeHTML(retryActionLabel)
      return htmlDocument(
        title: safeTitle,
        body: "<h1>\(safeTitle)</h1><p>\(safeMessage)</p><button>\(safeRetryActionLabel)</button>"
      )
    }
  }

  private func escapeHTML(_ input: String) -> String {
    input
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&#39;")
  }

  private func htmlDocument(title: String, body: String) -> String {
    """
    <!doctype html>
    <html lang=\"en\">
      <head>
        <meta charset=\"utf-8\" />
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
        <title>\(title)</title>
      </head>
      <body>
        \(body)
      </body>
    </html>
    """
  }
}

private struct HTTPRequest {
  let method: String
  let path: String
  let headers: [String: String]
  let body: Data
}
