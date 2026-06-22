import Foundation
import Testing

@testable import GaiaCore

/// Integration test (Spec 009, Scenario 4 / FR-007/FR-008): when Hemera is
/// unavailable but a warm cache exists, the last snapshot is served marked stale
/// with the "Daten evtl. veraltet" warning — never demo data.
@Suite(.serialized)
struct HemeraStaleCacheSoftFailTests {
  @Test
  func servesStaleCachedSnapshotWhenHemeraUnavailable() async throws {
    let runtime = try RealDataTestSupport.makeRuntime()
    let courseID = "course-123"
    let cache = DashboardCache<String, DashboardSnapshot>()

    // Warm the cache with a previously fetched real snapshot.
    let warm = DashboardSnapshot(
      course: DashboardCourse(id: courseID, title: "Gaia Seminar"),
      participants: [DashboardParticipant(id: "u1", displayName: "Real Person", avatarURL: nil)],
      connection: DashboardConnectionStatus(aither: .connected, hemera: .connected),
      system: DashboardSystemMetrics(
        version: "1.0.0", serviceStatus: .healthy, lastUpdatedAt: RealDataTestSupport.now)
    )
    await cache.store(
      value: warm, for: courseID, now: RealDataTestSupport.now, ttl: 45)

    // Hemera now fails on every request.
    let downstream = DownstreamServiceClient(runtime: runtime) { request in
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
      return (Data(), response)
    }

    let client = HemeraDashboardClient.authenticated(
      baseURL: RealDataTestSupport.hemeraBaseURL,
      downstreamClient: downstream,
      cache: cache,
      ttl: 45
    )

    // Query past the TTL so the entry is stale (still usable), forcing a refetch
    // that fails and falls back to the cached value.
    let snapshot = await client.loadSnapshot(
      courseID: courseID,
      requestID: "req-stale",
      now: RealDataTestSupport.now.addingTimeInterval(50)
    )

    #expect(snapshot.isStale)
    #expect(snapshot.warningMessage == "Daten evtl. veraltet")
    #expect(snapshot.course.title == "Gaia Seminar")
    #expect(snapshot.participants.first?.displayName == "Real Person")
  }
}
