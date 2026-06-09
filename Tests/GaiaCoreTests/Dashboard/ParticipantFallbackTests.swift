import Foundation
import Testing

@testable import GaiaCore

@Suite(.serialized)
struct ParticipantFallbackTests {
  @Test
  func returnsDemoFallbackWhenNoCacheAndHemeraUnavailable() async {
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
    #expect(!snapshot.participants.isEmpty)
  }
}
