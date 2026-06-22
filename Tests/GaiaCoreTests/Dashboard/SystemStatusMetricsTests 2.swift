import Foundation
import Testing

@testable import GaiaCore

struct SystemStatusMetricsTests {
  @Test
  func serviceReturnsConfiguredVersionAndHealth() async {
    let now = Date(timeIntervalSince1970: 1_700_000_200)
    let service = SystemHealthService(version: "2.3.1")

    let metrics = await service.loadSystemMetrics(now: now)

    #expect(metrics.version == "2.3.1")
    #expect(metrics.serviceStatus == .healthy)
    #expect(metrics.lastUpdatedAt == now)
  }
}
