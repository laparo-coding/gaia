import Foundation
import Testing

@testable import GaiaCore

/// Integration tests (Spec 009) covering the live `DashboardService` wiring:
/// real-data load across all cards, and explicit failure on missing config.
@Suite(.serialized)
struct RealDataDashboardServiceTests {
  /// Scenario 1 + FR-006: real data populates all three data-bearing cards and
  /// carries no demo placeholders.
  @Test
  func liveServiceLoadsRealDataForAllCards() async throws {
    let runtime = try RealDataTestSupport.makeRuntime()
    let courseID = "course-123"
    let environment = [
      LocalEnvironment.hemeraBaseURLKey: RealDataTestSupport.hemeraBaseURL.absoluteString
    ]

    let service = try DashboardService.live(
      runtime: runtime,
      environment: environment,
      transport: { request in
        let path = request.url?.path ?? ""
        let body: Data
        if path.contains("participants") {
          body = RealDataTestSupport.participantsBody(courseID: courseID)
        } else if path.contains("system-health") {
          body = RealDataTestSupport.systemHealthBody()
        } else {
          body = RealDataTestSupport.statusBody()
        }
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil,
          headerFields: ["Content-Type": "application/json"])!
        return (body, response)
      }
    )

    let snapshot = await service.loadSnapshot(
      courseID: courseID, requestID: "req-live", now: RealDataTestSupport.now)

    // Connection Monitor card
    #expect(snapshot.connection.hemera == .connected)
    #expect(snapshot.connection.aither == .connected)
    // Participant Overview card (real names, no demo placeholders)
    #expect(snapshot.participants.map(\.displayName) == ["Real Person One", "Real Person Two"])
    #expect(!snapshot.participants.map(\.displayName).contains("Alex Example"))
    // System Status card
    #expect(snapshot.system.serviceStatus == .healthy)
    #expect(snapshot.system.version == "1.0.0")
    #expect(!snapshot.isStale)
  }

  /// Scenario 5 / FR-009/FR-010: unset Hemera base URL fails explicitly, never
  /// serving demo data.
  @Test
  func liveServiceFailsExplicitlyWhenHemeraBaseURLMissing() async throws {
    let runtime = try RealDataTestSupport.makeRuntime()

    #expect(throws: LocalEnvironment.ConfigurationError.self) {
      _ = try DashboardService.live(runtime: runtime, environment: [:])
    }
  }
}
