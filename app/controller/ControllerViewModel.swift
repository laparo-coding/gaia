#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
final class ControllerViewModel: ObservableObject {
  enum NavigationCommandKind: String {
    case previous
    case next
  }

  private struct PresentationResponse: Decodable {
    struct Slide: Decodable {
      let index: Int
      let fileName: String
      let htmlURL: String
      let notes: String
      let notesSource: String
      let title: String?
    }

    let courseId: String
    let presentationId: String
    let title: String
    let aspectRatio: String
    let activeSlideIndex: Int
    let slideCount: Int
    let slides: [Slide]
  }

  private struct NavigationResponse: Decodable {
    struct Slide: Decodable {
      let index: Int
      let fileName: String
      let htmlURL: String
      let notes: String
      let notesSource: String
      let title: String?
    }

    let activeSlideIndex: Int
    let slide: Slide
  }

  enum Status: Equatable {
    case idle
    case loading
    case ready
    case failed(message: String)
  }

  @Published private(set) var currentSlideHTML = "<html><body>Loading...</body></html>"
  @Published private(set) var currentNotes = "Platzhalter: Notizen sind noch nicht verfügbar."
  @Published private(set) var currentSlideTitle = "Lädt"
  @Published private(set) var slidePositionText = "-- / --"
  @Published private(set) var status: Status = .idle

  private let session = URLSession.shared
  private let baseURL: URL
  private var presentationID: String?
  private var slideCount: Int = 0
  private var currentSlideIndex: Int = 0
  private var courseID: String = "cmjpyww020000nocz1nry3ywm"

  /// Auto-Reconnect: alle 5s versuchen, Verbindung zu Hemera/Aither wiederherzustellen.
  private static let reconnectInterval: TimeInterval = 5
  private var reconnectTask: Task<Void, Never>?

  init(
    baseURL: URL = URL(string: "http://127.0.0.1:8080")!,
    courseID: String = "cmjpyww020000nocz1nry3ywm"
  ) {
    self.baseURL = baseURL
    self.courseID = courseID
  }

  func setCourseID(_ courseID: String) {
    let trimmed = courseID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return
    }
    self.courseID = trimmed
  }

  func loadInitialPresentation() async {
    await loadInitialPresentation(triggerReconnectOnFailure: true)
  }

  private func loadInitialPresentation(triggerReconnectOnFailure: Bool) async {
    status = .loading

    do {
      var components = URLComponents(
        url: baseURL.appendingPathComponent("api/controller/presentation"),
        resolvingAgainstBaseURL: false
      )
      components?.queryItems = [URLQueryItem(name: "courseId", value: courseID)]

      guard let endpoint = components?.url else {
        throw URLError(.badURL)
      }

      var request = URLRequest(url: endpoint)
      request.httpMethod = "GET"

      let (data, response) = try await session.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw URLError(.badServerResponse)
      }

      let payload = try JSONDecoder().decode(PresentationResponse.self, from: data)
      courseID = payload.courseId
      // "Seminar starten" muss immer die erste Folie zeigen.
      guard let firstSlide = payload.slides.first(where: { $0.index == 0 }) ?? payload.slides.first else {
        throw URLError(.cannotParseResponse)
      }

      presentationID = payload.presentationId
      currentSlideIndex = firstSlide.index
      slideCount = payload.slideCount
      currentSlideTitle = firstSlide.title ?? firstSlide.fileName
      slidePositionText = "\(firstSlide.index + 1) / \(payload.slideCount)"
      currentNotes = firstSlide.notes
      currentSlideHTML = try await fetchSlideHTML(from: firstSlide.htmlURL)
      status = .ready
    } catch {
      status = .failed(message: "Aither-Präsentation konnte nicht geladen werden.")
      if triggerReconnectOnFailure { startReconnectLoop() }
    }
  }

  func navigate(command: NavigationCommandKind) async {
    status = .loading

    do {
      guard let presentationID else {
        throw URLError(.userAuthenticationRequired)
      }

      // Build the endpoint URL once, including query items.
      let endpoint = baseURL.appendingPathComponent("api/controller/navigation")
      guard var components = URLComponents(
        url: endpoint,
        resolvingAgainstBaseURL: false
      ) else {
        throw URLError(.badURL)
      }
      components.queryItems = [URLQueryItem(name: "courseId", value: courseID)]
      guard let endpointURL = components.url else {
        throw URLError(.badURL)
      }

      // Create a single URLRequest with the resolved endpoint.
      let payload: [String: Any] = [
        "presentationId": presentationID,
        "command": command.rawValue,
        "fromIndex": currentSlideIndex,
        "requestId": UUID().uuidString,
      ]

      var request = URLRequest(url: endpointURL)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: payload)

      let (data, response) = try await session.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw URLError(.badServerResponse)
      }

      let navigation = try JSONDecoder().decode(NavigationResponse.self, from: data)
      currentSlideIndex = navigation.activeSlideIndex
      currentSlideTitle = navigation.slide.title ?? navigation.slide.fileName
      // Guard against slideCount == 0 (e.g. navigation before a presentation
      // loaded, or a malformed manifest) to avoid nonsensical "x / 0" output.
      slidePositionText = slideCount > 0
        ? "\(navigation.activeSlideIndex + 1) / \(slideCount)"
        : "-- / --"
      currentNotes = navigation.slide.notes
      currentSlideHTML = try await fetchSlideHTML(from: navigation.slide.htmlURL)

      status = .ready
    } catch {
      status = .failed(message: "Controller-Navigation fehlgeschlagen.")
      startReconnectLoop()
    }
  }

  private func fetchSlideHTML(from htmlURL: String) async throws -> String {
    guard let url = makeResolvedURL(from: htmlURL) else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let (data, response) = try await session.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }

    guard let html = String(data: data, encoding: .utf8) else {
      throw URLError(.cannotDecodeContentData)
    }

    return html
  }

  private func makeResolvedURL(from htmlURL: String) -> URL? {
    if let absolute = URL(string: htmlURL), absolute.scheme != nil {
      return absolute
    }

    if htmlURL.hasPrefix("/") {
      return URL(string: htmlURL, relativeTo: baseURL)?.absoluteURL
    }

    return baseURL
      .appendingPathComponent("api/controller/slides")
      .appendingPathComponent(htmlURL)
  }

  // MARK: - Auto-Reconnect (alle 5s bis Verbindung wiederhergestellt)

  private func startReconnectLoop() {
    reconnectTask?.cancel()
    reconnectTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: UInt64(Self.reconnectInterval * 1_000_000_000))
        guard let self, !Task.isCancelled else { return }
        await self.loadInitialPresentation(triggerReconnectOnFailure: false)
        if self.status == .ready { return }
      }
    }
  }

  private func stopReconnectLoop() {
    reconnectTask?.cancel()
    reconnectTask = nil
  }
}
#endif
