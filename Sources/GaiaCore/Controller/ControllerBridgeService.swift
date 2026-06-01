import Foundation

public actor ControllerBridgeService {
  private let client: AitherControllerClient
  private let telemetry: ControllerTelemetry
  private var manifestCache: [String: ControllerManifest] = [:]

  public init(client: AitherControllerClient, telemetry: ControllerTelemetry) {
    self.client = client
    self.telemetry = telemetry
  }

  public func loadPresentation(
    courseID: String,
    requestID: String,
    now: Date = Date()
  ) async -> AuthorizedRequestResult<ControllerManifest> {
    let result = await client.fetchManifest(
      courseID: courseID,
      requestID: requestID,
      now: now
    )

    if let manifest = result.value {
      manifestCache[courseID] = manifest
      return result
    }

    if let error = result.error {
      await telemetry.recordFailure(
        event: .manifestLoadFailed,
        requestID: requestID,
        error: error
      )
    }

    return result
  }

  public func navigate(
    courseID: String,
    command: NavigationCommand,
    requestID: String,
    now: Date = Date()
  ) async -> AuthorizedRequestResult<ControllerManifest> {
    guard let cachedManifest = manifestCache[courseID] else {
      let error = AuthenticationError.unsafeFailure(reason: "controller_manifest_not_cached")
      await telemetry.recordFailure(
        event: .bridgeOutOfSync,
        requestID: requestID,
        error: error
      )
      return AuthorizedRequestResult(value: nil, authorization: nil, error: error)
    }

    if cachedManifest.activeSlideIndex != command.fromIndex {
      let error = AuthenticationError.unsafeFailure(reason: "controller_out_of_sync")
      await telemetry.recordFailure(
        event: .bridgeOutOfSync,
        requestID: requestID,
        error: error
      )
      return AuthorizedRequestResult(value: nil, authorization: nil, error: error)
    }

    let navResult = await client.navigate(
      command: command,
      requestID: requestID,
      now: now
    )
    if let error = navResult.error {
      await telemetry.recordFailure(
        event: .navigationFailed,
        requestID: requestID,
        error: error
      )
      return AuthorizedRequestResult(
        value: nil,
        authorization: navResult.authorization,
        error: error
      )
    }

    guard let slide = navResult.value else {
      let error = AuthenticationError.unsafeFailure(
        reason: "controller_navigation_missing_slide"
      )
      await telemetry.recordFailure(
        event: .navigationFailed,
        requestID: requestID,
        error: error
      )
      return AuthorizedRequestResult(
        value: nil,
        authorization: navResult.authorization,
        error: error
      )
    }

    var updatedSlides = cachedManifest.slides
    guard updatedSlides.indices.contains(slide.index) else {
      let error = AuthenticationError.unsafeFailure(
        reason: "controller_navigation_index_out_of_bounds"
      )
      await telemetry.recordFailure(
        event: .navigationFailed,
        requestID: requestID,
        error: error
      )
      return AuthorizedRequestResult(
        value: nil,
        authorization: navResult.authorization,
        error: error
      )
    }

    updatedSlides[slide.index] = slide

    do {
      let updatedManifest = try ControllerManifest(
        courseID: cachedManifest.courseID,
        presentationID: cachedManifest.presentationID,
        title: cachedManifest.title,
        aspectRatio: cachedManifest.aspectRatio,
        activeSlideIndex: slide.index,
        lastUpdated: now,
        slides: updatedSlides
      )

      manifestCache[courseID] = updatedManifest
      return AuthorizedRequestResult(
        value: updatedManifest,
        authorization: navResult.authorization,
        error: nil
      )
    } catch {
      let authError = AuthenticationError.unsafeFailure(
        reason: "controller_manifest_rebuild_failed"
      )
      await telemetry.recordFailure(
        event: .navigationFailed,
        requestID: requestID,
        error: authError
      )
      return AuthorizedRequestResult(
        value: nil,
        authorization: navResult.authorization,
        error: authError
      )
    }
  }

  public func fetchSlideHTML(
    courseID: String,
    fileName: String,
    requestID: String,
    now: Date = Date()
  ) async -> AuthorizedRequestResult<String> {
    let result = await client.fetchSlideHTML(
      courseID: courseID,
      fileName: fileName,
      requestID: requestID,
      now: now
    )

    if let error = result.error {
      await telemetry.recordFailure(
        event: .slideHTMLFetchFailed,
        requestID: requestID,
        error: error
      )
    }

    return result
  }
}
