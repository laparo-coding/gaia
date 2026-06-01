import Foundation

public actor ServiceTokenCacheStore {
  private var entries: [DownstreamService: ServiceTokenCache] = [:]

  public init() {}

  public func cached(
    for service: DownstreamService,
    at date: Date,
    leewaySeconds: Int
  ) -> ServiceTokenCache? {
    guard let entry = entries[service] else {
      return nil
    }

    if entry.isExpired(at: date) {
      entries.removeValue(forKey: service)
      return nil
    }

    if entry.needsRefresh(at: date, leewaySeconds: leewaySeconds) {
      return nil
    }

    return entry
  }

  public func entry(for service: DownstreamService) -> ServiceTokenCache? {
    entries[service]
  }

  public func store(_ entry: ServiceTokenCache) {
    entries[entry.service] = entry.resettingRetry()
  }

  public func invalidate(service: DownstreamService) {
    entries.removeValue(forKey: service)
  }

  public func markRetryConsumed(service: DownstreamService) {
    guard let entry = entries[service] else {
      return
    }

    entries[service] = entry.consumingRetry()
  }
}
