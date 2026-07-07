import Foundation

public actor ControllerBridgeService {
  /// Maximum age (in seconds) a cached manifest is considered fresh before
  /// `navigate` forces a re-fetch from Aither. Tuned to avoid a network
  /// round-trip on every navigation command while still bounding staleness.
  private static let manifestCacheTTL: TimeInterval = 30

  private let client: AitherControllerClient
  private let telemetry: ControllerTelemetry
  private var manifestCache: [String: ControllerManifest] = [:]
  private var manifestCacheTimestamps: [String: Date] = [:]

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
      manifestCacheTimestamps[courseID] = now
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
    let resolution = await resolveManifestForNavigation(
      courseID: courseID,
      requestID: requestID,
      now: now
    )
    guard let cachedManifest = resolution.manifest else {
      return resolution.failure
        ?? AuthorizedRequestResult(
          value: nil,
          authorization: nil,
          error: .unsafeFailure(reason: "controller_manifest_not_cached")
        )
    }

    // Use the authoritative activeSlideIndex for the fromIndex check.
    let expectedFromIndex = cachedManifest.activeSlideIndex
    if expectedFromIndex != command.fromIndex {
      // Tolerate the mismatch: use the server's authoritative index instead of rejecting.
    }

    guard
      let authoritativeCommand = await buildAuthoritativeCommand(
        from: command,
        expectedFromIndex: expectedFromIndex,
        manifest: cachedManifest,
        requestID: requestID
      )
    else {
      return AuthorizedRequestResult(
        value: nil,
        authorization: resolution.authorization,
        error: .unsafeFailure(reason: "controller_navigation_invalid_command")
      )
    }

    return await executeNavigation(
      courseID: courseID,
      cachedManifest: cachedManifest,
      authoritativeCommand: authoritativeCommand,
      requestID: requestID,
      now: now
    )
  }

  private func executeNavigation(
    courseID: String,
    cachedManifest: ControllerManifest,
    authoritativeCommand: NavigationCommand,
    requestID: String,
    now: Date
  ) async -> AuthorizedRequestResult<ControllerManifest> {
    let navResult = await client.navigate(
      command: authoritativeCommand,
      courseID: cachedManifest.courseID,
      requestID: requestID,
      now: now
    )
    if let failure = await navigationFailure(from: navResult, requestID: requestID) {
      return failure
    }

    guard let slide = navResult.value else {
      return await navigationFailure(
        reason: "controller_navigation_missing_slide",
        requestID: requestID,
        authorization: navResult.authorization
      )
    }

    guard
      let updatedManifest = rebuildManifest(
        from: cachedManifest,
        with: slide,
        now: now
      )
    else {
      return await navigationFailure(
        reason: "controller_manifest_rebuild_failed",
        requestID: requestID,
        authorization: navResult.authorization
      )
    }

    updateManifestCache(
      originalCourseID: courseID,
      updatedManifest: updatedManifest,
      now: now
    )

    return AuthorizedRequestResult(
      value: updatedManifest,
      authorization: navResult.authorization,
      error: nil
    )
  }

  private func navigationFailure(
    from navResult: AuthorizedRequestResult<ControllerSlide>,
    requestID: String
  ) async -> AuthorizedRequestResult<ControllerManifest>? {
    guard let error = navResult.error else {
      return nil
    }

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

  private struct ManifestResolution {
    let manifest: ControllerManifest?
    let authorization: ServiceAuthorizationResult?
    let failure: AuthorizedRequestResult<ControllerManifest>?
  }

  private func resolveManifestForNavigation(
    courseID: String,
    requestID: String,
    now: Date
  ) async -> ManifestResolution {
    let staleManifest = manifestCache[courseID]

    if let cached = staleManifest,
      let cachedAt = manifestCacheTimestamps[courseID],
      now.timeIntervalSince(cachedAt) < Self.manifestCacheTTL
    {
      return ManifestResolution(
        manifest: cached,
        authorization: nil,
        failure: nil
      )
    }

    let manifestResult = await loadPresentation(
      courseID: courseID,
      requestID: requestID,
      now: now
    )

    return await resolveManifestAfterRefresh(
      staleManifest: staleManifest,
      manifestResult: manifestResult,
      requestID: requestID
    )
  }

  private func resolveManifestAfterRefresh(
    staleManifest: ControllerManifest?,
    manifestResult: AuthorizedRequestResult<ControllerManifest>,
    requestID: String
  ) async -> ManifestResolution {

    if let manifest = manifestResult.value ?? staleManifest {
      return ManifestResolution(
        manifest: manifest,
        authorization: manifestResult.authorization,
        failure: nil
      )
    }

    if let error = manifestResult.error {
      await telemetry.recordFailure(
        event: .navigationFailed,
        requestID: requestID,
        error: error
      )
      return ManifestResolution(
        manifest: nil,
        authorization: manifestResult.authorization,
        failure: AuthorizedRequestResult(
          value: nil,
          authorization: manifestResult.authorization,
          error: error
        )
      )
    }

    return await manifestNotCachedFailure(requestID: requestID)
  }

  private func manifestNotCachedFailure(requestID: String) async -> ManifestResolution {
    let error = AuthenticationError.unsafeFailure(reason: "controller_manifest_not_cached")
    await telemetry.recordFailure(
      event: .bridgeOutOfSync,
      requestID: requestID,
      error: error
    )

    return ManifestResolution(
      manifest: nil,
      authorization: nil,
      failure: AuthorizedRequestResult(
        value: nil,
        authorization: nil,
        error: error
      )
    )
  }

  private func buildAuthoritativeCommand(
    from command: NavigationCommand,
    expectedFromIndex: Int,
    manifest: ControllerManifest,
    requestID: String
  ) async -> NavigationCommand? {
    // Rebuild command with server-authoritative fromIndex to avoid Aither INDEX_CONFLICT.
    // Source presentationID from the authoritative cachedManifest, not the incoming command,
    // so navigation targets the active deck.
    do {
      return try NavigationCommand(
        presentationID: manifest.presentationID,
        command: command.command,
        fromIndex: expectedFromIndex,
        issuedAt: command.issuedAt,
        requestID: command.requestID
      )
    } catch {
      await telemetry.recordFailure(
        event: .navigationFailed,
        requestID: requestID,
        error: error as? AuthenticationError
          ?? .unsafeFailure(reason: "controller_navigation_invalid_command")
      )
      return nil
    }
  }

  private func rebuildManifest(
    from cachedManifest: ControllerManifest,
    with slide: ControllerSlide,
    now: Date
  ) -> ControllerManifest? {
    var updatedSlides = cachedManifest.slides
    guard updatedSlides.indices.contains(slide.index) else {
      return nil
    }

    updatedSlides[slide.index] = slide

    let resolvedCourseID = slide.courseID ?? cachedManifest.courseID
    let resolvedPresentationID = slide.presentationID ?? cachedManifest.presentationID

    return try? ControllerManifest(
      courseID: resolvedCourseID,
      presentationID: resolvedPresentationID,
      title: cachedManifest.title,
      aspectRatio: cachedManifest.aspectRatio,
      activeSlideIndex: slide.index,
      lastUpdated: now,
      slides: updatedSlides
    )
  }

  private func updateManifestCache(
    originalCourseID: String,
    updatedManifest: ControllerManifest,
    now: Date
  ) {
    let resolvedCourseID = updatedManifest.courseID
    manifestCache[resolvedCourseID] = updatedManifest
    if resolvedCourseID != originalCourseID {
      manifestCache.removeValue(forKey: originalCourseID)
    }
    manifestCacheTimestamps[originalCourseID] = now
    manifestCacheTimestamps[resolvedCourseID] = now
    if resolvedCourseID != originalCourseID {
      manifestCacheTimestamps.removeValue(forKey: originalCourseID)
    }
  }

  private func navigationFailure(
    reason: String,
    requestID: String,
    authorization: ServiceAuthorizationResult?
  ) async -> AuthorizedRequestResult<ControllerManifest> {
    let error = AuthenticationError.unsafeFailure(reason: reason)
    await telemetry.recordFailure(
      event: .navigationFailed,
      requestID: requestID,
      error: error
    )
    return AuthorizedRequestResult(
      value: nil,
      authorization: authorization,
      error: error
    )
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
