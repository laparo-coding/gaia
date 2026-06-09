#if canImport(SwiftUI)
import Foundation
#if canImport(GaiaCore)
import GaiaCore
#endif

@MainActor
final class DashboardViewModel: ObservableObject {
  private struct SessionStatePayload: Decodable {
    let status: String
    let role: String?
  }

  private struct DashboardStatusPayload: Decodable {
    struct Connection: Decodable {
      let aither: String
      let hemera: String
    }

    struct System: Decodable {
      let serviceStatus: String
      let lastUpdatedAt: Date
    }

    let connection: Connection
    let system: System
  }

  private struct DashboardParticipantsPayload: Decodable {
    struct Course: Decodable {
      let id: String
      let title: String
    }

    struct Participant: Decodable {
      let id: String
      let displayName: String
      let avatarUrl: String?
    }

    struct Cache: Decodable {
      let isStale: Bool
    }

    let course: Course
    let participants: [Participant]
    let cache: Cache
  }

  private struct DashboardSystemHealthPayload: Decodable {
    let version: String
    let serviceStatus: String
    let lastUpdatedAt: Date
  }

  enum Status: Equatable {
    case idle
    case loading
    case ready
    case failed(message: String)
  }

  @Published private(set) var snapshot = DashboardSnapshot.demo()
  @Published private(set) var status: Status = .idle
  @Published private(set) var canStartSeminar = false

  private let session: URLSession
  private let baseURL: URL
  private let decoder: JSONDecoder
  private let policy = SeminarStartPolicy(requiredRole: "moderator")
  private var currentRole: String?

  init(
    baseURL: URL = URL(string: "http://127.0.0.1:8080")!,
    session: URLSession = .shared
  ) {
    self.baseURL = baseURL
    self.session = session
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  func loadDashboard(courseID: String = "course-123") async {
    status = .loading

    do {
      async let sessionState = fetchSessionState()
      async let statusPayload = fetchStatusPayload()
      async let participantPayload = fetchParticipantPayload(courseID: courseID)
      async let systemPayload = fetchSystemHealthPayload()

      let loadedRole = try await sessionState.role
      let loadedStatus = try await sessionState.status
      let loadedConnection = try await statusPayload
      let loadedParticipants = try await participantPayload
      let loadedSystem = try await systemPayload

      currentRole = loadedRole

      let runtimeState = RuntimeSessionState(
        session: try UserSession(
          sessionId: loadedStatus == "authenticated" ? UUID().uuidString : nil,
          subjectId: loadedStatus == "authenticated" ? "dashboard-user" : nil,
          role: loadedRole,
          status: UserSessionStatus(rawValue: loadedStatus) ?? .unauthenticated,
          issuedAt: Date(),
          expiresAt: Date().addingTimeInterval(3600),
          returnToPath: nil
        )
      )
      canStartSeminar = policy.canStartSeminar(session: runtimeState)

      snapshot = DashboardSnapshot(
        course: DashboardCourse(id: loadedParticipants.course.id, title: loadedParticipants.course.title),
        participants: loadedParticipants.participants.map {
          DashboardParticipant(id: $0.id, displayName: $0.displayName, avatarURL: $0.avatarUrl.flatMap(URL.init(string:)))
        },
        connection: DashboardConnectionStatus(
          aither: DashboardConnectionState(rawValue: loadedConnection.aither) ?? .disconnected,
          hemera: DashboardConnectionState(rawValue: loadedConnection.hemera) ?? .disconnected
        ),
        system: DashboardSystemMetrics(
          version: loadedSystem.version,
          serviceStatus: DashboardServiceHealth(rawValue: loadedSystem.serviceStatus) ?? .degraded,
          lastUpdatedAt: loadedSystem.lastUpdatedAt
        ),
        isStale: loadedParticipants.cache.isStale,
        warningMessage: loadedParticipants.cache.isStale ? "Daten evtl. veraltet" : nil
      )
      status = .ready
    } catch {
      snapshot = DashboardSnapshot.demo().markingStale()
      canStartSeminar = false
      status = .failed(message: "Dashboard-Daten konnten nicht geladen werden.")
    }
  }

  private func fetchSessionState() async throws -> (status: String, role: String?) {
    let payload: SessionStatePayload = try await fetchDecoded(path: "api/auth/session")
    return (payload.status, payload.role)
  }

  private func fetchStatusPayload() async throws -> DashboardStatusPayload.Connection {
    let payload: DashboardStatusPayload = try await fetchDecoded(path: "api/dashboard/status")
    return payload.connection
  }

  private func fetchParticipantPayload(courseID: String) async throws -> DashboardParticipantsPayload {
    try await fetchDecoded(path: "api/dashboard/participants?courseId=\(courseID)")
  }

  private func fetchSystemHealthPayload() async throws -> DashboardSystemHealthPayload {
    try await fetchDecoded(path: "api/dashboard/system-health")
  }

  private func fetchDecoded<Value: Decodable>(path: String) async throws -> Value {
    guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
      throw URLError(.badURL)
    }

    let (data, response) = try await session.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }

    return try decoder.decode(Value.self, from: data)
  }
}
#endif
