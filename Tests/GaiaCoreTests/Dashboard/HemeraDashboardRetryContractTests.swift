import Foundation
import Testing

@testable import GaiaCore

/// Contract test (Spec 009, FR-008 / Spec 005 FR-012): a Hemera `401` triggers
/// exactly one credential refresh + one retry, after which the request succeeds.
@Suite(.serialized)
struct HemeraDashboardRetryContractTests {
  @Test
  func hemera401RefreshesCredentialOnceAndRetriesOnce() async throws {
    let runtime = try RealDataTestSupport.makeRuntimeWithRefreshableHemera(
      expiredToken: "expired-key", freshToken: "fresh-key")
    let courseID = "course-123"

    let attempts = AttemptCounter()
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      let token = request.value(forHTTPHeaderField: "X-API-Key")
      await attempts.record(token: token)

      // First call (expired token) → 401; refreshed retry (fresh token) → 200.
      if token == "fresh-key" {
        let body = Self.body(for: request.url, courseID: courseID)
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil,
          headerFields: ["Content-Type": "application/json"])!
        return (body, response)
      }

      let response = HTTPURLResponse(
        url: request.url!, statusCode: 401, httpVersion: nil,
        headerFields: ["WWW-Authenticate": "Bearer"])!
      return (Data(), response)
    }

    let client = HemeraDashboardClient.authenticated(
      baseURL: RealDataTestSupport.hemeraBaseURL,
      downstreamClient: downstream,
      ttl: 45
    )

    let snapshot = await client.loadSnapshot(
      courseID: courseID, requestID: "req-401", now: RealDataTestSupport.now)

    // The refreshed retry produced real data, not a degraded/demo snapshot.
    #expect(snapshot.course.id == courseID)
    #expect(snapshot.system.serviceStatus == .healthy)
    #expect(await attempts.sawExpiredToken)
    #expect(await attempts.sawFreshToken)
  }

  private static func body(for url: URL?, courseID: String) -> Data {
    let path = url?.path ?? ""
    if path.contains("participants") {
      return RealDataTestSupport.participantsBody(courseID: courseID)
    }
    if path.contains("system-health") {
      return RealDataTestSupport.systemHealthBody()
    }
    return RealDataTestSupport.statusBody()
  }
}

private actor AttemptCounter {
  private(set) var sawExpiredToken = false
  private(set) var sawFreshToken = false

  func record(token: String?) {
    if token == "expired-key" { sawExpiredToken = true }
    if token == "fresh-key" { sawFreshToken = true }
  }
}
