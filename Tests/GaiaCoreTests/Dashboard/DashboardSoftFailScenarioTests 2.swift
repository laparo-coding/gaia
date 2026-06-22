import Foundation
import Testing

@testable import GaiaCore

@Suite(.serialized)
struct DashboardSoftFailScenarioTests {
  @Test
  func returnsStaleSnapshotWhenBackendFailsButCacheHasValue() async {
    let now = Date(timeIntervalSince1970: 1_700_000_100)
    let cache = DashboardCache<String, DashboardSnapshot>()
    await cache.store(
      value: .demo(courseID: "course-1", now: now), for: "course-1", now: now, ttl: 45)

    let session = makeDashboardTestSession { request in
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
      return (response, Data())
    }

    let client = HemeraDashboardClient(
      baseURL: URL(string: "http://localhost:8080")!,
      session: session,
      cache: cache,
      ttl: 45
    )

    let snapshot = await client.loadSnapshot(
      courseID: "course-1", requestID: "req-1", now: now.addingTimeInterval(50))

    #expect(snapshot.isStale)
    #expect(snapshot.warningMessage == "Daten evtl. veraltet")
    #expect(snapshot.course.id == "course-1")
  }
}
