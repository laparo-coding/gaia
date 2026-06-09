import Foundation

public enum DashboardCacheFreshness: Equatable, Sendable {
  case missing
  case fresh
  case stale
  case expired
}

public struct DashboardCacheEntry<Value: Sendable>: Equatable, Sendable where Value: Equatable {
  public let value: Value
  public let storedAt: Date
  public let ttl: TimeInterval

  public init(value: Value, storedAt: Date, ttl: TimeInterval) {
    self.value = value
    self.storedAt = storedAt
    self.ttl = ttl
  }

  public func freshness(at date: Date) -> DashboardCacheFreshness {
    let age = date.timeIntervalSince(storedAt)
    if age < 0 {
      return .fresh
    }
    if age <= ttl {
      return .fresh
    }
    if age <= ttl * 2 {
      return .stale
    }
    return .expired
  }
}

public actor DashboardCache<Key: Hashable & Sendable, Value: Sendable> where Value: Equatable {
  private var entries: [Key: DashboardCacheEntry<Value>] = [:]

  public init() {}

  public func store(value: Value, for key: Key, now: Date = Date(), ttl: TimeInterval) {
    entries[key] = DashboardCacheEntry(value: value, storedAt: now, ttl: ttl)
  }

  public func entry(for key: Key) -> DashboardCacheEntry<Value>? {
    entries[key]
  }

  public func freshness(for key: Key, at date: Date = Date()) -> DashboardCacheFreshness {
    guard let entry = entries[key] else {
      return .missing
    }

    return entry.freshness(at: date)
  }

  public func valueIfUsable(for key: Key, at date: Date = Date()) -> Value? {
    guard let entry = entries[key] else {
      return nil
    }

    switch entry.freshness(at: date) {
    case .expired, .missing:
      return nil
    case .fresh, .stale:
      return entry.value
    }
  }
}
