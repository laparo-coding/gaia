#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
final class ControllerViewModel: ObservableObject {
  enum NavigationCommandKind: String {
    case previous
    case next
  }

  private struct DemoSlide {
    let title: String
    let html: String
    let notes: String
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
  private var currentSlideIndex: Int = 0
  private var courseID: String = "course-123"
  private var demoSlides: [DemoSlide] = []

  init(
    baseURL: URL = URL(string: "http://127.0.0.1:8080")!,
    courseID: String = "course-123"
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
      guard let activeSlide = payload.slides.first(where: { $0.index == payload.activeSlideIndex }) else {
        throw URLError(.cannotParseResponse)
      }

      presentationID = payload.presentationId
      currentSlideIndex = payload.activeSlideIndex
      currentSlideTitle = activeSlide.title ?? activeSlide.fileName
      slidePositionText = "\(payload.activeSlideIndex + 1) / \(payload.slideCount)"
      currentNotes = activeSlide.notes
      currentSlideHTML = try await fetchSlideHTML(from: activeSlide.htmlURL)
      status = .ready
    } catch {
      applyLocalDemoPresentation()
    }
  }

  func navigate(command: NavigationCommandKind) async {
    status = .loading

    do {
      if presentationID == "local-demo" {
        try navigateLocalDemo(command: command)
        status = .ready
        return
      }

      guard let presentationID else {
        throw URLError(.userAuthenticationRequired)
      }

      var request = URLRequest(url: baseURL.appendingPathComponent("api/controller/navigation"))
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      let payload: [String: Any] = [
        "presentationId": presentationID,
        "command": command.rawValue,
        "fromIndex": currentSlideIndex,
        "requestId": UUID().uuidString,
      ]

      request.httpBody = try JSONSerialization.data(withJSONObject: payload)

      let (data, response) = try await session.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw URLError(.badServerResponse)
      }

      let navigation = try JSONDecoder().decode(NavigationResponse.self, from: data)
      currentSlideIndex = navigation.activeSlideIndex
      currentSlideTitle = navigation.slide.title ?? navigation.slide.fileName
      currentNotes = navigation.slide.notes
      currentSlideHTML = try await fetchSlideHTML(from: navigation.slide.htmlURL)

      status = .ready
    } catch {
      status = .failed(message: "Controller-Navigation fehlgeschlagen.")
    }
  }

  private func applyLocalDemoPresentation() {
    demoSlides = [
      DemoSlide(
        title: "Offline-Vorschau",
        html: """
        <html>
          <head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\" /></head>
          <body style=\"margin:0;font-family:-apple-system,Helvetica,sans-serif;background:#f3f4f6;color:#111827;display:flex;align-items:center;justify-content:center;height:100vh;\">
            <div style=\"max-width:900px;padding:24px;text-align:center;\">
              <p style=\"margin:0 0 8px 0;font-size:18px;letter-spacing:0.04em;text-transform:uppercase;color:#0f766e;\">Offline-Vorschau</p>
              <h1 style=\"margin:0;font-size:48px;line-height:1.1;\">Gaia-Controller-Layout</h1>
            </div>
          </body>
        </html>
        """,
        notes: "Lokale Demo aktiv: Bridge-Endpunkt nicht erreichbar."
      ),
      DemoSlide(
        title: "Navigationsvorschau",
        html: """
        <html>
          <head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\" /></head>
          <body style=\"margin:0;font-family:-apple-system,Helvetica,sans-serif;background:#111827;color:#f9fafb;display:flex;align-items:center;justify-content:center;height:100vh;\">
            <div style=\"max-width:900px;padding:24px;text-align:center;\">
              <h2 style=\"margin:0 0 12px 0;font-size:42px;\">Navigationsvorschau</h2>
              <p style=\"margin:0;font-size:24px;color:#cbd5e1;\">Weiter / Zurück wechselt die lokalen Demo-Slides</p>
            </div>
          </body>
        </html>
        """,
        notes: "Tipp: Mit Weiter / Zurück kannst du den Button-Ablauf prüfen."
      ),
      DemoSlide(
        title: "Controller bereit",
        html: """
        <html>
          <head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\" /></head>
          <body style=\"margin:0;font-family:-apple-system,Helvetica,sans-serif;background:linear-gradient(135deg,#fee2e2,#dbeafe);color:#0f172a;display:flex;align-items:center;justify-content:center;height:100vh;\">
            <div style=\"max-width:900px;padding:24px;text-align:center;\">
              <h2 style=\"margin:0 0 12px 0;font-size:42px;\">Controller bereit</h2>
              <p style=\"margin:0;font-size:24px;\">Sobald der Server läuft, ersetzt Live-Inhalt diese Vorschau.</p>
            </div>
          </body>
        </html>
        """,
        notes: "Wenn GaiaAuthenticationApp auf :8080 läuft, wird automatisch Live-Content geladen."
      ),
    ]

    presentationID = "local-demo"
    currentSlideIndex = 0
    currentSlideTitle = demoSlides[0].title
    slidePositionText = "1 / \(demoSlides.count)"
    currentSlideHTML = demoSlides[0].html
    currentNotes = demoSlides[0].notes
    status = .ready
  }

  private func navigateLocalDemo(command: NavigationCommandKind) throws {
    guard !demoSlides.isEmpty else {
      throw URLError(.cannotParseResponse)
    }

    let nextIndex: Int
    switch command {
    case .previous:
      nextIndex = max(0, currentSlideIndex - 1)
    case .next:
      nextIndex = min(demoSlides.count - 1, currentSlideIndex + 1)
    }

    currentSlideIndex = nextIndex
  currentSlideTitle = demoSlides[nextIndex].title
    slidePositionText = "\(nextIndex + 1) / \(demoSlides.count)"
    currentSlideHTML = demoSlides[nextIndex].html
    currentNotes = demoSlides[nextIndex].notes
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
}
#endif
