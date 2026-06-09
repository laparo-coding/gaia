import Foundation

public protocol DashboardServiceProtocol: Sendable {
  func loadSnapshot(
    courseID: String,
    requestID: String,
    now: Date
  ) async -> DashboardSnapshot
}

public protocol DashboardStatusMonitoring: Sendable {
  func loadStatusBootstrap(
    courseID: String,
    requestID: String,
    now: Date
  ) async -> DashboardSnapshot
}
