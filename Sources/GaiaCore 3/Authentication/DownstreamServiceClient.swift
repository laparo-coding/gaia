import Foundation

public struct DownstreamServiceResponse: Equatable, Sendable {
  public let service: DownstreamService
  public let statusCode: Int
  public let body: Data
  public let headers: [String: String]
  public let attempt: Int

  public init(
    service: DownstreamService,
    statusCode: Int,
    body: Data,
    headers: [String: String],
    attempt: Int
  ) {
    self.service = service
    self.statusCode = statusCode
    self.body = body
    self.headers = headers
    self.attempt = attempt
  }
}

public struct DownstreamServiceClient: Sendable {
  public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  private let runtime: AuthenticationRuntime
  private let transport: Transport

  public init(
    runtime: AuthenticationRuntime,
    transport: @escaping Transport = { request in
      try await URLSession.shared.data(for: request)
    }
  ) {
    self.runtime = runtime
    self.transport = transport
  }

  public func send(
    service: DownstreamService,
    baseURL: URL,
    path: String,
    method: String,
    operation: String,
    requestId: String,
    body: Data? = nil,
    additionalHeaders: [String: String] = [:],
    now: Date = Date()
  ) async -> AuthorizedRequestResult<DownstreamServiceResponse> {
    await runtime.executeAuthorizedServiceRequest(
      service: service,
      operation: operation,
      requestId: requestId,
      now: now
    ) { token, attempt in
      let request = try Self.makeRequest(
        service: service,
        baseURL: baseURL,
        path: path,
        method: method,
        requestId: requestId,
        token: token,
        body: body,
        additionalHeaders: additionalHeaders
      )

      let (data, response) = try await transport(request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw AuthenticationError.serviceAuthorizationFailed(service: service)
      }

      if httpResponse.statusCode == 401 {
        throw AuthenticationError.downstreamAuthenticationExpired(
          service: service,
          signal: httpResponse.value(forHTTPHeaderField: "WWW-Authenticate")
            ?? String(httpResponse.statusCode)
        )
      }

      return DownstreamServiceResponse(
        service: service,
        statusCode: httpResponse.statusCode,
        body: data,
        headers: Self.normalizeHeaders(httpResponse),
        attempt: attempt
      )
    }
  }

  private static func makeRequest(
    service: DownstreamService,
    baseURL: URL,
    path: String,
    method: String,
    requestId: String,
    token: String,
    body: Data?,
    additionalHeaders: [String: String]
  ) throws -> URLRequest {
    let base = normalizedBaseURL(baseURL)
    let relativePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let url = relativePath.isEmpty ? base : base.appendingPathComponent(relativePath)
    guard url.scheme != nil else {
      throw AuthenticationError.unsafeFailure(reason: "invalid_downstream_url")
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(requestId, forHTTPHeaderField: "X-Request-ID")

    if body != nil {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    for (header, value) in additionalHeaders {
      request.setValue(value, forHTTPHeaderField: header)
    }

    switch service {
    case .hemera:
      request.setValue(token, forHTTPHeaderField: "X-API-Key")
    case .aither:
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    return request
  }

  private static func normalizedBaseURL(_ url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return url
    }

    if components.path.isEmpty {
      components.path = "/"
    }

    return components.url ?? url
  }

  private static func normalizeHeaders(_ response: HTTPURLResponse) -> [String: String] {
    var headers: [String: String] = [:]
    for (key, value) in response.allHeaderFields {
      headers[String(describing: key)] = String(describing: value)
    }
    return headers
  }
}
