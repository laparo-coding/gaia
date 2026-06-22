import Foundation
import Testing

@testable import GaiaCore

struct DashboardCacheTests {
  @Test
  func freshnessTransitionsFromFreshToStaleToExpired() async {
    let cache = DashboardCache<String, DashboardSnapshot>()
    let now = Date(timeIntervalSince1970: 1_000)
    let ttl: TimeInterval = 30

    await cache.store(value: .demo(now: now), for: "course-1", now: now, ttl: ttl)

    #expect(await cache.freshness(for: "course-1", at: now.addingTimeInterval(15)) == .fresh)
    #expect(await cache.freshness(for: "course-1", at: now.addingTimeInterval(45)) == .stale)
    #expect(await cache.freshness(for: "course-1", at: now.addingTimeInterval(65)) == .expired)
  }

  @Test
  func staleValueRemainsUsableButExpiredDoesNot() async {
    let cache = DashboardCache<String, DashboardSnapshot>()
    let now = Date(timeIntervalSince1970: 2_000)

    await cache.store(value: .demo(now: now), for: "course-1", now: now, ttl: 20)

    let staleValue = await cache.valueIfUsable(for: "course-1", at: now.addingTimeInterval(35))
    let expiredValue = await cache.valueIfUsable(for: "course-1", at: now.addingTimeInterval(50))

    #expect(staleValue != nil)
    #expect(expiredValue == nil)
  }
}
