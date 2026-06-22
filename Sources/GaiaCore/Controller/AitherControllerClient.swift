import Foundation

public struct AitherControllerClient: Sendable {
  private struct SuccessEnvelope<Value: Decodable>: Decodable {
    let success: Bool
    let data: Value
  }

  private struct ManifestResponse: Decodable {
    struct SlideResponse: Decodable {
      let index: Int
      let fileName: String
      let noteTitle: String?
      let noteBody: String?
    }

    let courseId: String
    let presentationId: String
    let title: String
    let aspectRatio: String
    let activeSlideIndex: Int
    let lastUpdated: Date?
    let slides: [SlideResponse]
  }

  private struct NavigationRequest: Encodable {
    let presentationId: String
    let command: String
    let fromIndex: Int
    let requestId: String
  }

  private struct NavigationResponse: Decodable {
    let presentationId: String
    let activeSlideIndex: Int
    let fileName: String
    let noteTitle: String?
    let noteBody: String?
    let lastUpdated: Date?
  }

  public let bridgeBaseURL: URL
  public let aitherBaseURL: URL
  public let placeholderPrefix: String

  private let serviceClient: DownstreamServiceClient
  private let decoder: JSONDecoder

  public init(
    bridgeBaseURL: URL,
    aitherBaseURL: URL,
    serviceClient: DownstreamServiceClient,
    placeholderPrefix: String = "Placeholder:"
  ) {
    self.bridgeBaseURL = bridgeBaseURL
    self.aitherBaseURL = aitherBaseURL
    self.serviceClient = serviceClient
    self.placeholderPrefix = placeholderPrefix

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  public func fetchManifest(
    courseID: String,
    requestID: String,
    now: Date = Date()
  ) async -> AuthorizedRequestResult<ControllerManifest> {
    let path = "api/slides/controller?courseId=\(encodedQueryValue(courseID))"
    let upstream = await serviceClient.send(
      service: .aither,
      baseURL: aitherBaseURL,
      path: path,
      method: "GET",
      operation: "controller_manifest",
      requestId: requestID,
      now: now
    )

    if let error = upstream.error {
      return AuthorizedRequestResult(
        value: nil,
        authorization: upstream.authorization,
        error: error
      )
    }

    guard let response = upstream.value else {
      return AuthorizedRequestResult(
        value: nil,
        authorization: upstream.authorization,
        error: .serviceAuthorizationFailed(service: .aither)
      )
    }

    do {
      let payload = try decoder.decode(SuccessEnvelope<ManifestResponse>.self, from: response.body)
      let manifest = try mapManifest(payload.data)
      return AuthorizedRequestResult(
        value: manifest,
        authorization: upstream.authorization,
        error: nil
      )
    } catch {
      return AuthorizedRequestResult(
        value: nil,
        authorization: upstream.authorization,
        error: .unsafeFailure(reason: "controller_manifest_decode_failed")
      )
    }
  }

  public func navigate(
    command: NavigationCommand,
    requestID: String,
    now: Date = Date()
  ) async -> AuthorizedRequestResult<ControllerSlide> {
    let body = NavigationRequest(
      presentationId: command.presentationID,
      command: command.command.rawValue,
      fromIndex: command.fromIndex,
      requestId: requestID
    )

    guard let payload = try? JSONEncoder().encode(body) else {
      return AuthorizedRequestResult(
        value: nil,
        authorization: nil,
        error: .unsafeFailure(reason: "controller_navigation_encode_failed")
      )
    }

    let upstream = await serviceClient.send(
      service: .aither,
      baseURL: aitherBaseURL,
      path: "api/slides/controller/navigation",
      method: "POST",
      operation: "controller_navigation",
      requestId: requestID,
      body: payload,
      now: now
    )

    if let error = upstream.error {
      return AuthorizedRequestResult(
        value: nil,
        authorization: upstream.authorization,
        error: error
      )
    }

    guard let response = upstream.value else {
      return AuthorizedRequestResult(
        value: nil,
        authorization: upstream.authorization,
        error: .serviceAuthorizationFailed(service: .aither)
      )
    }

    do {
      let payload = try decoder.decode(
        SuccessEnvelope<NavigationResponse>.self, from: response.body)
      let slide = try mapSlide(payload.data)
      return AuthorizedRequestResult(
        value: slide,
        authorization: upstream.authorization,
        error: nil
      )
    } catch {
      return AuthorizedRequestResult(
        value: nil,
        authorization: upstream.authorization,
        error: .unsafeFailure(reason: "controller_navigation_decode_failed")
      )
    }
  }

  public func fetchSlideHTML(
    courseID: String,
    fileName: String,
    requestID: String,
    now: Date = Date()
  ) async -> AuthorizedRequestResult<String> {
    let path =
      "api/slides/view?courseId=\(encodedQueryValue(courseID))&file=\(encodedQueryValue(fileName))"
    let upstream = await serviceClient.send(
      service: .aither,
      baseURL: aitherBaseURL,
      path: path,
      method: "GET",
      operation: "controller_slide_html",
      requestId: requestID,
      additionalHeaders: [
        "Accept": "text/html; charset=utf-8"
      ],
      now: now
    )

    if let error = upstream.error {
      return AuthorizedRequestResult(
        value: nil,
        authorization: upstream.authorization,
        error: error
      )
    }

    guard let response = upstream.value else {
      return AuthorizedRequestResult(
        value: nil,
        authorization: upstream.authorization,
        error: .serviceAuthorizationFailed(service: .aither)
      )
    }

    guard let html = String(data: response.body, encoding: .utf8) else {
      return AuthorizedRequestResult(
        value: nil,
        authorization: upstream.authorization,
        error: .unsafeFailure(reason: "controller_slide_html_decode_failed")
      )
    }

    return AuthorizedRequestResult(
      value: html,
      authorization: upstream.authorization,
      error: nil
    )
  }

  private func mapManifest(_ response: ManifestResponse) throws -> ControllerManifest {
    let slides = try response.slides.map { try mapSlide($0) }
    return try ControllerManifest(
      courseID: response.courseId,
      presentationID: response.presentationId,
      title: response.title,
      aspectRatio: response.aspectRatio,
      activeSlideIndex: response.activeSlideIndex,
      lastUpdated: response.lastUpdated,
      slides: slides
    )
  }

  private func mapSlide(_ response: ManifestResponse.SlideResponse) throws -> ControllerSlide {
    let htmlURL = makeBridgeSlideURL(fileName: response.fileName)

    let notes: String

    if let upstreamNotes = response.noteBody {
      if upstreamNotes.isEmpty {
        notes = "\(placeholderPrefix) Notes are not available yet."
      } else {
        notes = upstreamNotes
      }
    } else {
      notes = "\(placeholderPrefix) Notes are not available yet."
    }

    let notesSource: ControllerNotesSource
    notesSource = response.noteBody?.isEmpty == false ? .upstream : .placeholder

    return try ControllerSlide(
      index: response.index,
      fileName: response.fileName,
      htmlURL: htmlURL,
      notes: notes,
      notesSource: notesSource,
      title: response.noteTitle,
      contentState: .ready,
      etag: nil
    )
  }

  private func mapSlide(_ response: NavigationResponse) throws -> ControllerSlide {
    let htmlURL = makeBridgeSlideURL(fileName: response.fileName)

    let notes: String

    if let upstreamNotes = response.noteBody {
      if upstreamNotes.isEmpty {
        notes = "\(placeholderPrefix) Notes are not available yet."
      } else {
        notes = upstreamNotes
      }
    } else {
      notes = "\(placeholderPrefix) Notes are not available yet."
    }

    let notesSource: ControllerNotesSource
    notesSource = response.noteBody?.isEmpty == false ? .upstream : .placeholder

    return try ControllerSlide(
      index: response.activeSlideIndex,
      fileName: response.fileName,
      htmlURL: htmlURL,
      notes: notes,
      notesSource: notesSource,
      title: response.noteTitle,
      contentState: .ready,
      etag: nil
    )
  }

  private func makeBridgeSlideURL(fileName: String) -> URL {
    bridgeBaseURL
      .appendingPathComponent("api/controller/slides")
      .appendingPathComponent(fileName)
  }

  private func encodedQueryValue(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
  }
}
