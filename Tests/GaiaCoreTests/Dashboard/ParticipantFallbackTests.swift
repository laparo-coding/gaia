import Foundation
import Testing

@testable import GaiaCore

@Suite(.serialized)
struct ParticipantFallbackTests {
  /// FR-001/FR-002 + Constitution VI: when Hemera is unavailable and no cache
  /// exists, the production path MUST NOT serve demo/placeholder data. It returns
  /// an explicit degraded snapshot (empty participants, unavailable status) with
  /// the stale warning instead.
  @Test
  func returnsDegradedSnapshotWithoutDemoDataWhenNoCacheAndHemeraUnavailable() async {
    let session = makeDashboardTestSession { request in
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
      return (response, Data())
    }

    let client = HemeraDashboardClient(
      baseURL: URL(string: "http://localhost:8080")!,
      session: session,
      cache: DashboardCache<String, DashboardSnapshot>(),
      ttl: 45
    )

    let snapshot = await client.loadSnapshot(courseID: "course-fallback", requestID: "req-2")

    #expect(snapshot.isStale)
    #expect(snapshot.course.id == "course-fallback")
    #expect(snapshot.warningMessage == "Daten evtl. veraltet")
    // No placeholder participants on the production path (FR-002).
    #expect(snapshot.participants.isEmpty)
    #expect(snapshot.system.serviceStatus == .unavailable)
    // The well-known demo placeholder names must never leak through.
    let names = snapshot.participants.map(\.displayName)
    #expect(!names.contains("Alex Example"))
    #expect(!names.contains("Mara Muster"))
    #expect(!names.contains("Sam Sample"))
  }
}
