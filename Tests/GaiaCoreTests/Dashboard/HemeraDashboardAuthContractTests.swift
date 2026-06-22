import Foundation
import Testing

@testable import GaiaCore

/// Contract tests (Spec 009, FR-005): the authenticated Hemera dashboard client
/// routes through the Spec 005 downstream auth stack and attaches `X-API-Key`,
/// and 200 payloads map correctly onto `DashboardSnapshot`.
@Suite(.serialized)
struct HemeraDashboardAuthContractTests {
  @Test
  func hemeraRequestsCarryApiKeyHeaderAndMapToSnapshot() async throws {
    let runtime = try RealDataTestSupport.makeRuntime(hemeraToken: "hemera-test-key")
    let courseID = "course-123"

    let observedHeaders = HeaderRecorder()
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      await observedHeaders.record(
        apiKey: request.value(forHTTPHeaderField: "X-API-Key"),
        authorization: request.value(forHTTPHeaderField: "Authorization")
      )

      let body = Self.body(for: request.url, courseID: courseID)
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil,
        headerFields: ["Content-Type": "application/json"])!
      return (body, response)
    }

    let client = HemeraDashboardClient.authenticated(
      baseURL: RealDataTestSupport.hemeraBaseURL,
      downstreamClient: downstream,
      ttl: 45
    )

    let snapshot = await client.loadSnapshot(
      courseID: courseID, requestID: "req-1", now: RealDataTestSupport.now)

    // FR-005: every Hemera request carried X-API-Key and no Bearer header.
    #expect(await observedHeaders.allCarriedApiKey)
    #expect(await observedHeaders.neverCarriedBearer)

    // FR-012 mapping: real data mapped onto the snapshot (no demo placeholders).
    #expect(snapshot.course.id == courseID)
    #expect(snapshot.course.title == "Gaia Seminar")
    #expect(snapshot.participants.map(\.displayName) == ["Real Person One", "Real Person Two"])
    #expect(snapshot.connection.hemera == .connected)
    #expect(snapshot.connection.aither == .connected)
    #expect(snapshot.system.serviceStatus == .healthy)
    #expect(snapshot.system.version == "1.0.0")
    #expect(!snapshot.isStale)
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

private actor HeaderRecorder {
  private(set) var allCarriedApiKey = true
  private(set) var neverCarriedBearer = true

  func record(apiKey: String?, authorization: String?) {
    if apiKey == nil || apiKey?.isEmpty == true {
      allCarriedApiKey = false
    }
    if authorization != nil {
      neverCarriedBearer = false
    }
  }
}
