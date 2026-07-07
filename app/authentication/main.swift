import Darwin
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
try await configuration.seedDevelopmentSessionIfNeeded(runtime: runtime)
private let server = try AuthenticationHTTPServer(configuration: configuration, runtime: runtime)

try server.start()

private struct AuthenticationAppConfiguration {
  let host: String
  let port: UInt16
  let baseURL: URL
  let aitherBaseURL: URL
  let controllerDefaultCourseID: String
  let seedControllerDevelopmentSession: Bool
  private let runtimeEnvironment: LocalEnvironment.RuntimeEnvironment
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

    runtimeEnvironment = LocalEnvironment.runtimeEnvironment(in: environment)
    aitherBaseURL = try LocalEnvironment.preferredServiceBaseURL(
      .aither,
      in: environment,
      runtimeEnvironment: runtimeEnvironment
    )

    if let configuredCourseID = environment["GAIA_CONTROLLER_COURSE_ID"],
      !configuredCourseID.isEmpty
    {
      controllerDefaultCourseID = configuredCourseID
    } else {
      controllerDefaultCourseID = "course-123"
    }

    seedControllerDevelopmentSession = Self.resolveSeedControllerDevelopmentSession(
      configuredValue: environment["GAIA_SEED_CONTROLLER_DEV_SESSION"],
      runtimeEnvironment: runtimeEnvironment,
      host: host,
      baseURL: baseURL
    )

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

  func seedDevelopmentSessionIfNeeded(runtime: AuthenticationRuntime) async throws {
    guard seedControllerDevelopmentSession else {
      return
    }

    guard runtimeEnvironment != .production else {
      fputs(
        "Ignoring GAIA_SEED_CONTROLLER_DEV_SESSION in production runtime.\n",
        stderr
      )
      return
    }

    guard Self.isLoopbackHost(host), Self.isLoopbackHost(baseURL.host) else {
      fputs(
        "Ignoring GAIA_SEED_CONTROLLER_DEV_SESSION because host/base URL is not loopback-only.\n",
        stderr
      )
      return
    }

    let now = Date()
    _ = try await runtime.completeSignIn(
      sessionId: "local-controller-dev-session",
      subjectId: "local-controller-dev-user",
      role: "moderator",
      issuedAt: now,
      expiresAt: now.addingTimeInterval(8 * 60 * 60)
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

  private static func parseBooleanEnvironmentValue(_ value: String?) -> Bool {
    guard let value else {
      return false
    }

    switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "1", "true", "yes", "on":
      return true
    default:
      return false
    }
  }

  private static func resolveSeedControllerDevelopmentSession(
    configuredValue: String?,
    runtimeEnvironment: LocalEnvironment.RuntimeEnvironment,
    host: String,
    baseURL: URL
  ) -> Bool {
    if configuredValue != nil {
      return parseBooleanEnvironmentValue(configuredValue)
    }

    // Default to an authenticated local controller session for loopback-only
    // development runs to keep simulator startup friction-free.
    // Explicitly configured GAIA_SEED_CONTROLLER_DEV_SESSION=true still works
    // above; this default path only applies in development (not test/CI).
    guard runtimeEnvironment == .development else {
      return false
    }

    return isLoopbackHost(host) && isLoopbackHost(baseURL.host)
  }

  private static func isLoopbackHost(_ host: String?) -> Bool {
    guard let host = host?.lowercased() else {
      return false
    }

    if host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]" {
      return true
    }

    var address = in_addr()
    guard inet_pton(AF_INET, host, &address) == 1 else {
      return false
    }

    let ipv4HostOrder = UInt32(bigEndian: address.s_addr)
    return (ipv4HostOrder & 0xFF00_0000) == 0x7F00_0000
  }
}

private final class AuthenticationHTTPServer: @unchecked Sendable {
  private static let maxRequestBufferBytes = 1_048_576
  private static let shutdownSignals: [Int32] = [SIGINT, SIGTERM]

  private let configuration: AuthenticationAppConfiguration
  private let runtime: AuthenticationRuntime
  private let controllerBridgeService: ControllerBridgeService
  private let controllerDefaultCourseID: String
  private let listener: NWListener
  private let queue = DispatchQueue(label: "gaia.authentication.http")
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let shutdownGroup = DispatchGroup()
  private let shutdownStateQueue = DispatchQueue(label: "gaia.authentication.shutdown")
  private var signalSources: [DispatchSourceSignal] = []
  private var didSignalShutdown = false

  init(configuration: AuthenticationAppConfiguration, runtime: AuthenticationRuntime) throws {
    self.configuration = configuration
    self.runtime = runtime
    let downstreamServiceClient = DownstreamServiceClient(runtime: runtime)
    let controllerClient = AitherControllerClient(
      bridgeBaseURL: configuration.baseURL,
      aitherBaseURL: configuration.aitherBaseURL,
      serviceClient: downstreamServiceClient
    )
    controllerBridgeService = ControllerBridgeService(
      client: controllerClient,
      telemetry: ControllerTelemetry()
    )
    controllerDefaultCourseID = configuration.controllerDefaultCourseID
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
    shutdownGroup.enter()
    installSignalHandlers()

    listener.stateUpdateHandler = { [weak self] state in
      guard let self else {
        return
      }

      switch state {
      case .failed(let error):
        fputs("GaiaAuthenticationApp listener failed: \(error)\n", stderr)
        self.listener.cancel()
        self.completeShutdownIfNeeded()
      case .cancelled:
        self.completeShutdownIfNeeded()
      default:
        break
      }
    }

    listener.newConnectionHandler = { [weak self] connection in
      self?.handle(connection: connection)
    }
    listener.start(queue: queue)

    print("GaiaAuthenticationApp listening on \(configuration.baseURL.absoluteString)")
    shutdownGroup.wait()
  }

  private func installSignalHandlers() {
    signalSources = Self.shutdownSignals.map { shutdownSignal in
      signal(shutdownSignal, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: shutdownSignal, queue: queue)
      source.setEventHandler { [weak self] in
        fputs("GaiaAuthenticationApp shutting down after signal \(shutdownSignal).\n", stderr)
        self?.listener.cancel()
        self?.completeShutdownIfNeeded()
      }
      source.resume()
      return source
    }
  }

  private func completeShutdownIfNeeded() {
    shutdownStateQueue.sync {
      guard !didSignalShutdown else {
        return
      }
      didSignalShutdown = true
      shutdownGroup.leave()
    }
  }

  private func handle(connection: NWConnection) {
    connection.start(queue: queue)
    receive(on: connection, buffer: Data())
  }

  private var streamingConnections: [ObjectIdentifier: NWConnection] = [:]
  private let streamingConnectionsLock = NSLock()
  private var pumpTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
  private let pumpTasksLock = NSLock()

  private func receive(on connection: NWConnection, buffer: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
      [weak self] data, _, isComplete, error in
      guard let self else {
        connection.cancel()
        return
      }

      if let error {
        fputs("Receive error: \(error)\n", stderr)
        self.removeStreamingConnection(connection)
        connection.cancel()
        return
      }

      if isComplete {
        self.removeStreamingConnection(connection)
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
        self.removeStreamingConnection(connection)
        connection.cancel()
        return
      }

      guard let request = self.parseRequest(from: updatedBuffer) else {
        self.receive(on: connection, buffer: updatedBuffer)
        return
      }

      Task {
        let response = await self.makeResponse(for: request, on: connection)
        guard let response else {
          return
        }
        connection.send(
          content: response,
          completion: .contentProcessed { _ in
            self.removeStreamingConnection(connection)
            connection.cancel()
          })
      }
    }
  }

  private func makeResponse(for request: HTTPRequest, on connection: NWConnection) async -> Data? {
    let requestId = request.headers["x-request-id"] ?? UUID().uuidString
    let parsedRequest = parseRouteRequest(path: request.path)
    let routePath = parsedRequest.path
    let queryItems = parsedRequest.queryItems

    if requiresControllerAuthorization(for: routePath) {
      let session = await runtime.readSession()
      guard isAuthorizedControllerSession(session) else {
        return makeJSONResponse(
          statusCode: 401,
          body: AuthenticationErrorPayload(
            error: "no_active_session",
            message: "Controller routes require an active authenticated session.",
            requestId: requestId
          )
        )
      }
    }

    switch (request.method, routePath) {
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

    case ("GET", ControllerPresentationRoute.path):
      guard let courseID = validatedControllerCourseID(from: queryItems["courseId"]) else {
        return makeJSONResponse(
          statusCode: 400,
          body: AuthenticationErrorPayload(
            error: "invalid_request",
            message: "courseId is invalid.",
            requestId: requestId
          )
        )
      }

      let response = await ControllerPresentationRoute.get(
        bridgeService: controllerBridgeService,
        courseID: courseID,
        requestID: requestId
      )
      return makeJSONResponse(statusCode: response.statusCode, body: response.body)

    case ("POST", ControllerNavigationRoute.path):
      guard let payload = try? decoder.decode(ControllerNavigationPayload.self, from: request.body)
      else {
        return makeJSONResponse(
          statusCode: 400,
          body: AuthenticationErrorPayload(
            error: "invalid_request",
            message: "Controller navigation payload could not be decoded.",
            requestId: requestId
          )
        )
      }

      guard let courseID = validatedControllerCourseID(from: queryItems["courseId"]) else {
        return makeJSONResponse(
          statusCode: 400,
          body: AuthenticationErrorPayload(
            error: "invalid_request",
            message: "courseId is invalid.",
            requestId: requestId
          )
        )
      }

      let response = await ControllerNavigationRoute.post(
        bridgeService: controllerBridgeService,
        courseID: courseID,
        payload: payload,
        requestID: requestId
      )
      return makeJSONResponse(statusCode: response.statusCode, body: response.body)

    case ("GET", DashboardRouteHandlers.statusPath):
      let response = await DashboardRouteHandlers.getStatus(
        runtime: runtime,
        environment: environment,
        now: Date()
      )
      return makeJSONResponse(statusCode: response.statusCode, body: response.body)

    case ("GET", DashboardRouteHandlers.participantsPath):
      guard let courseID = validatedControllerCourseID(from: queryItems["courseId"]) else {
        return makeJSONResponse(
          statusCode: 400,
          body: AuthenticationErrorPayload(
            error: "invalid_request",
            message: "courseId is invalid.",
            requestId: requestId
          )
        )
      }

      let response = await DashboardRouteHandlers.getParticipants(
        runtime: runtime,
        environment: environment,
        courseID: courseID
      )
      return makeJSONResponse(statusCode: response.statusCode, body: response.body)

    case ("GET", DashboardRouteHandlers.systemHealthPath):
      let response = await DashboardRouteHandlers.getSystemHealth(
        runtime: runtime,
        environment: environment,
        now: Date()
      )
      return makeJSONResponse(statusCode: response.statusCode, body: response.body)

    case ("GET", DashboardRouteHandlers.statusEventsPath):
      startStatusEventStream(connection: connection)
      return nil

    default:
      if request.method == "GET",
        let fileName = ControllerSlidesRoute.fileName(from: routePath)
      {
        guard let courseID = validatedControllerCourseID(from: queryItems["courseId"]) else {
          return makeJSONResponse(
            statusCode: 400,
            body: AuthenticationErrorPayload(
              error: "invalid_request",
              message: "courseId is invalid.",
              requestId: requestId
            )
          )
        }

        let response = await ControllerSlidesRoute.get(
          bridgeService: controllerBridgeService,
          courseID: courseID,
          fileName: fileName,
          requestID: requestId
        )
        return makeControllerSlidesResponse(response)
      }

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

  private func makeEventStreamResponse(statusCode: Int, body: String) -> Data {
    makeHTTPResponse(
      statusCode: statusCode,
      contentType: "text/event-stream; charset=utf-8",
      body: Data(body.utf8)
    )
  }

  private func makeSSEHeaders(statusCode: Int) -> Data {
    let statusText: String
    switch statusCode {
    case 200: statusText = "OK"
    case 204: statusText = "No Content"
    case 400: statusText = "Bad Request"
    case 401: statusText = "Unauthorized"
    case 404: statusText = "Not Found"
    case 503: statusText = "Service Unavailable"
    case 502: statusText = "Bad Gateway"
    default: statusText = "Internal Server Error"
    }

    var headers = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
    headers += "Content-Type: text/event-stream; charset=utf-8\r\n"
    headers += "Cache-Control: no-cache\r\n"
    headers += "X-Accel-Buffering: no\r\n"
    headers += "Connection: keep-alive\r\n"
    headers += "Transfer-Encoding: chunked\r\n"
    headers += "\r\n"
    return Data(headers.utf8)
  }

  private func registerStreamingConnection(_ connection: NWConnection) {
    streamingConnectionsLock.lock()
    streamingConnections[ObjectIdentifier(connection)] = connection
    streamingConnectionsLock.unlock()
  }

  private func removeStreamingConnection(_ connection: NWConnection) {
    streamingConnectionsLock.lock()
    streamingConnections.removeValue(forKey: ObjectIdentifier(connection))
    streamingConnectionsLock.unlock()
  }

  private func isStreamingConnection(_ connection: NWConnection) -> Bool {
    streamingConnectionsLock.lock()
    defer { streamingConnectionsLock.unlock() }
    return streamingConnections[ObjectIdentifier(connection)] != nil
  }

  private func startStatusEventStream(connection: NWConnection) {
    let key = ObjectIdentifier(connection)
    streamingConnectionsLock.lock()
    streamingConnections[key] = connection
    streamingConnectionsLock.unlock()

    let stream = DashboardRouteHandlers.getStatusEvents(
      now: Date(),
      isCancelled: { [weak self, weak connection] in
        guard let self, let connection else { return true }
        return !self.isStreamingConnection(connection)
      }
    )

    let headers = makeSSEHeaders(statusCode: 200)
    connection.send(
      content: headers,
      completion: .contentProcessed { [weak self] error in
        guard let self else {
          connection.cancel()
          return
        }

        if let error {
          fputs("SSE header send failed: \(error)\n", stderr)
          self.removeStreamingConnection(connection)
          connection.cancel()
          return
        }

        guard self.isStreamingConnection(connection) else {
          connection.cancel()
          return
        }

        self.pumpStatusEventStream(connection: connection, stream: stream)
      }
    )
  }

  private func pumpStatusEventStream(
    connection: NWConnection,
    stream: AsyncStream<String>
  ) {
    let pumpTask = Task<Void, Never> { [weak self] in
      await self?.runStatusEventPump(connection: connection, stream: stream)
    }

    pumpTasksLock.lock()
    if let previous = pumpTasks[ObjectIdentifier(connection)] {
      previous.cancel()
    }
    pumpTasks[ObjectIdentifier(connection)] = pumpTask
    pumpTasksLock.unlock()
  }

  private func runStatusEventPump(
    connection: NWConnection,
    stream: AsyncStream<String>
  ) async {
    defer {
      removeStreamingConnection(connection)
      removePumpTask(for: connection)
      Self.cancelConnection(connection)
    }

    for await chunk in stream {
      if Task.isCancelled {
        break
      }

      if !isStreamingConnection(connection) {
        break
      }

      let framed = HTTPChunkedTransfer.encodeChunk(chunk)
      let sendError: Error? = await withCheckedContinuation {
        (continuation: CheckedContinuation<Error?, Never>) in
        connection.send(
          content: framed,
          completion: .contentProcessed { error in
            continuation.resume(returning: error)
          }
        )
      }

      if let sendError {
        if Self.shouldLogSendError(sendError) {
          fputs("SSE chunk send failed: \(sendError)\n", stderr)
        }
        break
      }

      if !isStreamingConnection(connection) {
        break
      }
    }

    if isStreamingConnection(connection) {
      let sendError: Error? = await withCheckedContinuation {
        (continuation: CheckedContinuation<Error?, Never>) in
        connection.send(
          content: HTTPChunkedTransfer.terminator(),
          completion: .contentProcessed { error in
            continuation.resume(returning: error)
          }
        )
      }
      if let sendError, Self.shouldLogSendError(sendError) {
        fputs("SSE terminator send failed: \(sendError)\n", stderr)
      }
    }
  }

  /// POSIX 57 (ENOTCONN) / POSIX 32 (EPIPE) / NWConnection `.cancelled`
  /// errors indicate the peer has gone away; they are part of the normal
  /// shutdown handshake and should not pollute the log.
  private static func shouldLogSendError(_ error: Error) -> Bool {
    if let posix = error as? POSIXError {
      switch posix.code {
      case .ENOTCONN, .EPIPE, .ECANCELED:
        return false
      default:
        return true
      }
    }
    if let nwError = error as? NWError, nwError.debugDescription.contains("cancelled") {
      return false
    }
    return true
  }

  private func removePumpTask(for connection: NWConnection) {
    pumpTasksLock.lock()
    pumpTasks.removeValue(forKey: ObjectIdentifier(connection))
    pumpTasksLock.unlock()
  }

  private static func cancelConnection(_ connection: NWConnection) {
    let state = connection.state
    switch state {
    case .cancelled, .failed:
      return
    default:
      connection.cancel()
    }
  }

  private static func encodeChunkedFrame(_ frame: String) -> Data {
    HTTPChunkedTransfer.encodeChunk(frame)
  }

  private func makeHTTPResponse(statusCode: Int, contentType: String, body: Data) -> Data {
    let statusText: String
    switch statusCode {
    case 200: statusText = "OK"
    case 204: statusText = "No Content"
    case 400: statusText = "Bad Request"
    case 401: statusText = "Unauthorized"
    case 404: statusText = "Not Found"
    case 503: statusText = "Service Unavailable"
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

  private func parseRouteRequest(path: String) -> (path: String, queryItems: [String: String]) {
    if path.hasPrefix("http://") || path.hasPrefix("https://"),
      let components = URLComponents(string: path)
    {
      let resolvedPath = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
      return (
        path: resolvedPath, queryItems: parseQueryItems(from: components.percentEncodedQuery ?? "")
      )
    }

    let segments = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
    let rawPath = String(segments.first ?? "")
    let rawQuery = segments.count > 1 ? String(segments[1]) : ""
    let resolvedPath = rawPath.isEmpty ? "/" : rawPath

    return (path: resolvedPath, queryItems: parseQueryItems(from: rawQuery))
  }

  private func parseQueryItems(from rawQuery: String) -> [String: String] {
    URLQueryCodec.queryDictionary(fromPercentEncodedQuery: rawQuery)
  }

  private func validatedControllerCourseID(from queryCourseID: String?) -> String? {
    let candidate = (queryCourseID ?? controllerDefaultCourseID)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !candidate.isEmpty, candidate.count <= 128 else {
      return nil
    }

    guard candidate.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
      return nil
    }

    return candidate
  }

  private func requiresControllerAuthorization(for path: String) -> Bool {
    path.hasPrefix("/api/controller/") || path.hasPrefix("/api/dashboard/")
  }

  private func isAuthorizedControllerSession(_ session: RuntimeSessionState) -> Bool {
    guard session.status == .authenticated else {
      return false
    }

    guard let expiresAt = session.expiresAt else {
      return false
    }

    return expiresAt > Date()
  }

  private func makeControllerSlidesResponse(
    _ response: AuthenticationRouteResponse<ControllerSlidesRouteBody>
  ) -> Data {
    switch response.body {
    case .html(let html):
      return makeHTMLResponse(statusCode: response.statusCode, body: html)
    case .error(let payload):
      return makeJSONResponse(statusCode: response.statusCode, body: payload)
    case nil:
      return makeJSONResponse(
        statusCode: response.statusCode,
        body: AuthenticationErrorPayload(
          error: "controller_slide_failed",
          message: "Controller slide could not be loaded.",
          requestId: nil
        )
      )
    }
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
