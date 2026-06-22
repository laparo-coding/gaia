import Foundation

public enum DashboardConnectionState: String, Codable, Sendable {
  case connected
  case disconnected
  case connecting
}

public enum DashboardServiceHealth: String, Codable, Sendable {
  case healthy
  case degraded
  case unavailable
}

public struct DashboardConnectionStatus: Equatable, Sendable {
  public let aither: DashboardConnectionState
  public let hemera: DashboardConnectionState

  public init(aither: DashboardConnectionState, hemera: DashboardConnectionState) {
    self.aither = aither
    self.hemera = hemera
  }
}

public struct DashboardCourse: Equatable, Sendable {
  public let id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

public struct DashboardParticipant: Equatable, Sendable, Identifiable {
  public let id: String
  public let displayName: String
  public let avatarURL: URL?

  public init(id: String, displayName: String, avatarURL: URL?) {
    self.id = id
    self.displayName = displayName
    self.avatarURL = avatarURL
  }
}

public struct DashboardSystemMetrics: Equatable, Sendable {
  public let version: String
  public let serviceStatus: DashboardServiceHealth
  public let lastUpdatedAt: Date

  public init(version: String, serviceStatus: DashboardServiceHealth, lastUpdatedAt: Date) {
    self.version = version
    self.serviceStatus = serviceStatus
    self.lastUpdatedAt = lastUpdatedAt
  }
}

public struct DashboardSnapshot: Equatable, Sendable {
  public let course: DashboardCourse
  public let participants: [DashboardParticipant]
  public let connection: DashboardConnectionStatus
  public let system: DashboardSystemMetrics
  public let isStale: Bool
  public let warningMessage: String?

  public init(
    course: DashboardCourse,
    participants: [DashboardParticipant],
    connection: DashboardConnectionStatus,
    system: DashboardSystemMetrics,
    isStale: Bool = false,
    warningMessage: String? = nil
  ) {
    self.course = course
    self.participants = participants
    self.connection = connection
    self.system = system
    self.isStale = isStale
    self.warningMessage = warningMessage
  }

  /// Placeholder snapshot for **tests and SwiftUI previews only**.
  ///
  /// - Important: This MUST NOT be used on production runtime/data paths.
  ///   Placeholder runtime behavior is forbidden for production-critical code
  ///   paths (Constitution VI; FR-001/FR-002). The live fetch path degrades via
  ///   `degraded(courseID:now:)` or a stale cache instead.
  public static func demo(courseID: String = "course-123", now: Date = Date()) -> DashboardSnapshot
  {
    DashboardSnapshot(
      course: DashboardCourse(id: courseID, title: "Gaia Seminar"),
      participants: [
        DashboardParticipant(
          id: "user-1",
          displayName: "Alex Example",
          avatarURL: nil
        ),
        DashboardParticipant(
          id: "user-2",
          displayName: "Mara Muster",
          avatarURL: nil
        ),
        DashboardParticipant(
          id: "user-3",
          displayName: "Sam Sample",
          avatarURL: nil
        ),
      ],
      connection: DashboardConnectionStatus(aither: .connected, hemera: .connected),
      system: DashboardSystemMetrics(
        version: "1.0.0",
        serviceStatus: .healthy,
        lastUpdatedAt: now
      )
    )
  }

  /// Explicit degraded snapshot served on the production path when a fetch fails
  /// and no usable cache exists.
  ///
  /// Carries **no placeholder participant data** (FR-001/FR-002): an empty
  /// participant list, `unavailable` service status, and the stale warning so
  /// only the affected card degrades (soft-fail, FR-007).
  public static func degraded(
    courseID: String,
    now: Date = Date()
  ) -> DashboardSnapshot {
    DashboardSnapshot(
      course: DashboardCourse(id: courseID, title: ""),
      participants: [],
      connection: DashboardConnectionStatus(aither: .disconnected, hemera: .disconnected),
      system: DashboardSystemMetrics(
        version: "",
        serviceStatus: .unavailable,
        lastUpdatedAt: now
      ),
      isStale: true,
      warningMessage: "Daten evtl. veraltet"
    )
  }

  public func markingStale(message: String = "Daten evtl. veraltet") -> DashboardSnapshot {
    DashboardSnapshot(
      course: course,
      participants: participants,
      connection: connection,
      system: system,
      isStale: true,
      warningMessage: message
    )
  }
}
