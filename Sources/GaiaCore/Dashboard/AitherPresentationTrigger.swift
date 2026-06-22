import Foundation

/// Slide/presentation trigger for Aither (Spec 009, FR-004).
///
/// Aither is used **only** for slide/presentation triggers and is never a source
/// of dashboard card data. All requests are routed through the Spec 005 auth
/// stack (`DownstreamServiceClient`), which attaches `Authorization: Bearer` and
/// reuses the one-retry-on-`401` behavior.
public struct AitherPresentationTrigger: Sendable {
  private let baseURL: URL
  private let downstreamClient: DownstreamServiceClient
  private let operation: String

  public init(
    baseURL: URL,
    downstreamClient: DownstreamServiceClient,
    operation: String = "presentation:trigger"
  ) {
    self.baseURL = baseURL
    self.downstreamClient = downstreamClient
    self.operation = operation
  }

  /// Advances the presentation for the given course.
  ///
  /// - Returns: `true` when Aither accepted the trigger (2xx), otherwise `false`.
  ///   Failures degrade gracefully (no crash, no placeholder data).
  public func advance(
    courseID: String,
    requestID: String,
    now: Date = Date()
  ) async -> Bool {
    await trigger(action: "advance", courseID: courseID, requestID: requestID, now: now)
  }

  /// Jumps to a specific slide index for the given course.
  public func jump(
    to slideIndex: Int,
    courseID: String,
    requestID: String,
    now: Date = Date()
  ) async -> Bool {
    await trigger(
      action: "jump", courseID: courseID, slideIndex: slideIndex, requestID: requestID, now: now)
  }

  private func trigger(
    action: String,
    courseID: String,
    slideIndex: Int? = nil,
    requestID: String,
    now: Date
  ) async -> Bool {
    let payload = TriggerPayload(courseId: courseID, action: action, slideIndex: slideIndex)
    let body = try? JSONEncoder().encode(payload)

    let result = await downstreamClient.send(
      service: .aither,
      baseURL: baseURL,
      path: "/api/presentation/trigger",
      method: "POST",
      operation: operation,
      requestId: requestID,
      body: body,
      now: now
    )

    guard result.error == nil, let response = result.value else {
      return false
    }

    return (200...299).contains(response.statusCode)
  }

  private struct TriggerPayload: Encodable {
    let courseId: String
    let action: String
    let slideIndex: Int?
  }
}
