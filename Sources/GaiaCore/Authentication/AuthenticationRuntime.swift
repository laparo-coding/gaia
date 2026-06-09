import Foundation

public struct RuntimeServiceAuthorizationState: Equatable, Sendable {
  public let service: DownstreamService
  public let status: ServiceAuthorizationStatus
  public let retryOnExpiry: Bool
  public let expiresAt: Date?

  public init(result: ServiceAuthorizationResult) {
    service = result.service
    status = result.status
    retryOnExpiry = result.retryOnExpiry
    expiresAt = result.expiresAt
  }
}

public actor AuthenticationRuntime {
  private let sessionManager: AuthenticationSessionManager
  private let interactiveProvider: any InteractiveAuthenticationProviding
  private let serviceCoordinator: ServiceAuthorizationCoordinator

  public init(
    sessionManager: AuthenticationSessionManager,
    interactiveProvider: any InteractiveAuthenticationProviding,
    serviceCoordinator: ServiceAuthorizationCoordinator
  ) {
    self.sessionManager = sessionManager
    self.interactiveProvider = interactiveProvider
    self.serviceCoordinator = serviceCoordinator
  }

  public func readSession() async -> RuntimeSessionState {
    RuntimeSessionState(session: await sessionManager.currentSession())
  }

  public func beginSignIn(
    returnToPath: String,
    requestId: String
  ) async throws -> InteractiveAuthenticationChallenge {
    let request = InteractiveAuthenticationRequest(
      returnToPath: returnToPath,
      requestId: requestId
    )
    _ = try await sessionManager.startSignIn(returnToPath: returnToPath)

    do {
      return try await interactiveProvider.beginAuthentication(request: request)
    } catch {
      _ = await sessionManager.failSignIn()
      throw error
    }
  }

  public func completeSignIn(
    sessionId: String,
    subjectId: String,
    role: String,
    issuedAt: Date,
    expiresAt: Date
  ) async throws -> RuntimeSessionState {
    let session = try await sessionManager.completeSignIn(
      sessionId: sessionId,
      subjectId: subjectId,
      role: role,
      issuedAt: issuedAt,
      expiresAt: expiresAt
    )

    return RuntimeSessionState(session: session)
  }

  public func failSignIn() async -> RuntimeSessionState {
    RuntimeSessionState(session: await sessionManager.failSignIn())
  }

  public func signOut() async -> RuntimeSessionState {
    RuntimeSessionState(session: await sessionManager.signOut())
  }

  public func authorizeService(
    service: DownstreamService,
    operation: String,
    requestId: String,
    now: Date,
    body: @escaping @Sendable (String, Int) async throws -> String = { token, _ in token }
  ) async -> RuntimeServiceAuthorizationState {
    let result = await executeAuthorizedServiceRequest(
      service: service,
      operation: operation,
      requestId: requestId,
      now: now,
      body: body
    )

    if let authorization = result.authorization {
      return RuntimeServiceAuthorizationState(result: authorization)
    }

    return RuntimeServiceAuthorizationState(
      result: ServiceAuthorizationResult(
        service: service,
        status: .degraded,
        retryOnExpiry: true,
        expiresAt: nil,
        token: nil,
        requestId: requestId
      )
    )
  }

  public func executeAuthorizedServiceRequest<Value: Sendable>(
    service: DownstreamService,
    operation: String,
    requestId: String,
    now: Date,
    body: @escaping @Sendable (String, Int) async throws -> Value
  ) async -> AuthorizedRequestResult<Value> {
    await serviceCoordinator.executeAuthorizedRequest(
      service: service,
      operation: operation,
      requestId: requestId,
      now: now,
      body: body
    )
  }
}
