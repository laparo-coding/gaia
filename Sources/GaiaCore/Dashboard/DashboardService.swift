import Foundation

public actor DashboardService: DashboardServiceProtocol {
  private let client: HemeraDashboardClient
  private let cache: DashboardCache<String, DashboardSnapshot>

  public init(client: HemeraDashboardClient, cache: DashboardCache<String, DashboardSnapshot>) {
    self.client = client
    self.cache = cache
  }

  public func loadSnapshot(
    courseID: String,
    requestID: String,
    now: Date = Date()
  ) async -> DashboardSnapshot {
    let snapshot = await client.loadSnapshot(courseID: courseID, requestID: requestID, now: now)
    await cache.store(value: snapshot, for: courseID, now: now, ttl: 45)
    return snapshot
  }
}
