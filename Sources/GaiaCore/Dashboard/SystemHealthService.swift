import Foundation

public protocol DashboardSystemHealthProviding: Sendable {
  func loadSystemMetrics(now: Date) async -> DashboardSystemMetrics
}

public struct SystemHealthService: DashboardSystemHealthProviding, Sendable {
  private let version: String

  public init(version: String? = nil) {
    if let version, !version.isEmpty {
      self.version = version
    } else {
      self.version =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "1.0.0"
    }
  }

  public func loadSystemMetrics(now: Date = Date()) async -> DashboardSystemMetrics {
    DashboardSystemMetrics(version: version, serviceStatus: .healthy, lastUpdatedAt: now)
  }
}
