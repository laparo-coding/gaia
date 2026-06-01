import Foundation

public struct ServiceAuthorizationCoordinator: Sendable {
  public let cacheStore: ServiceTokenCacheStore
  public let hemeraAuthenticator: HemeraServiceAuthenticator
  public let aitherAuthenticator: AitherServiceAuthenticator
  public let telemetry: AuthenticationTelemetry

  public init(
    cacheStore: ServiceTokenCacheStore,
    hemeraAuthenticator: HemeraServiceAuthenticator,
    aitherAuthenticator: AitherServiceAuthenticator,
    telemetry: AuthenticationTelemetry
  ) {
    self.cacheStore = cacheStore
    self.hemeraAuthenticator = hemeraAuthenticator
    self.aitherAuthenticator = aitherAuthenticator
    self.telemetry = telemetry
  }

  public func executeAuthorizedRequest<Value: Sendable>(
    service: DownstreamService,
    operation: String,
    requestId: String,
    now: Date,
    body: @Sendable (String, Int) async throws -> Value
  ) async -> AuthorizedRequestResult<Value> {
    do {
      let initialAuthorization = try await authenticator(for: service).authorize(
        operation: operation,
        requestId: requestId,
        now: now
      )

      do {
        guard let initialToken = initialAuthorization.token else {
          let missingTokenError = AuthenticationError.serviceAuthorizationFailed(service: service)
          await telemetry.recordFailure(
            service: service, requestId: requestId, error: missingTokenError)
          return AuthorizedRequestResult(
            value: nil,
            authorization: degradedAuthorization(for: service, requestId: requestId),
            error: missingTokenError
          )
        }

        let value = try await body(initialToken, 0)
        return AuthorizedRequestResult(
          value: value,
          authorization: initialAuthorization,
          error: nil
        )
      } catch let error as AuthenticationError {
        guard case .downstreamAuthenticationExpired(let expiredService, _) = error,
          expiredService == service
        else {
          await telemetry.recordFailure(service: service, requestId: requestId, error: error)
          return AuthorizedRequestResult(
            value: nil,
            authorization: degradedAuthorization(for: service, requestId: requestId),
            error: error
          )
        }

        await cacheStore.invalidate(service: service)

        do {
          let retriedAuthorization = try await authenticator(for: service).authorize(
            operation: operation,
            requestId: requestId,
            now: now.addingTimeInterval(1)
          )
          guard let refreshedToken = retriedAuthorization.token else {
            let missingTokenError = AuthenticationError.serviceAuthorizationFailed(service: service)
            await cacheStore.invalidate(service: service)
            await telemetry.recordFailure(
              service: service, requestId: requestId, error: missingTokenError)
            return AuthorizedRequestResult(
              value: nil,
              authorization: degradedAuthorization(for: service, requestId: requestId),
              error: missingTokenError
            )
          }

          let value = try await body(refreshedToken, 1)
          let refreshedAuthorization = ServiceAuthorizationResult(
            service: service,
            status: .refreshed,
            retryOnExpiry: true,
            expiresAt: retriedAuthorization.expiresAt,
            token: retriedAuthorization.token,
            requestId: requestId
          )

          return AuthorizedRequestResult(
            value: value,
            authorization: refreshedAuthorization,
            error: nil
          )
        } catch let retryError as AuthenticationError {
          await cacheStore.invalidate(service: service)
          await telemetry.recordFailure(service: service, requestId: requestId, error: retryError)
          return AuthorizedRequestResult(
            value: nil,
            authorization: degradedAuthorization(for: service, requestId: requestId),
            error: retryError
          )
        } catch {
          let authError = AuthenticationError.serviceAuthorizationFailed(service: service)
          await cacheStore.invalidate(service: service)
          await telemetry.recordFailure(service: service, requestId: requestId, error: authError)
          return AuthorizedRequestResult(
            value: nil,
            authorization: degradedAuthorization(for: service, requestId: requestId),
            error: authError
          )
        }
      }
    } catch let error as AuthenticationError {
      await telemetry.recordFailure(service: service, requestId: requestId, error: error)
      return AuthorizedRequestResult(
        value: nil,
        authorization: degradedAuthorization(for: service, requestId: requestId),
        error: error
      )
    } catch {
      let authError = AuthenticationError.serviceAuthorizationFailed(service: service)
      await telemetry.recordFailure(service: service, requestId: requestId, error: authError)
      return AuthorizedRequestResult(
        value: nil,
        authorization: degradedAuthorization(for: service, requestId: requestId),
        error: authError
      )
    }
  }

  private func authenticator(for service: DownstreamService) -> any ServiceAuthenticating {
    switch service {
    case .hemera:
      return hemeraAuthenticator
    case .aither:
      return aitherAuthenticator
    }
  }

  private func degradedAuthorization(
    for service: DownstreamService,
    requestId: String
  ) -> ServiceAuthorizationResult {
    ServiceAuthorizationResult(
      service: service,
      status: .degraded,
      retryOnExpiry: true,
      expiresAt: nil,
      token: nil,
      requestId: requestId
    )
  }
}

public protocol ServiceAuthenticating: Sendable {
  func authorize(operation: String, requestId: String, now: Date) async throws
    -> ServiceAuthorizationResult
}

extension HemeraServiceAuthenticator: ServiceAuthenticating {}
extension AitherServiceAuthenticator: ServiceAuthenticating {}
