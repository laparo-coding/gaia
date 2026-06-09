import Foundation
import Testing

@testable import GaiaCore

struct ControllerInitialLoadScenarioTests {
  @Test
  func dashboardDemoSnapshotProvidesInitialUsableState() {
    let snapshot = DashboardSnapshot.demo(
      courseID: "course-123", now: Date(timeIntervalSince1970: 1_700_000_300))

    #expect(snapshot.course.id == "course-123")
    #expect(!snapshot.participants.isEmpty)
    #expect(snapshot.connection.aither == .connected)
  }
}
