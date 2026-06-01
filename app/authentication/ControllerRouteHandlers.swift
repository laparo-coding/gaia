import Foundation
import GaiaCore

struct ControllerPresentationPayload: Encodable {
  struct SlidePayload: Encodable {
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
  let slides: [SlidePayload]
}

enum ControllerPresentationRouteBody: Encodable {
  case presentation(ControllerPresentationPayload)
  case error(AuthenticationErrorPayload)

  func encode(to encoder: Encoder) throws {
    switch self {
    case .presentation(let payload):
      try payload.encode(to: encoder)
    case .error(let payload):
      try payload.encode(to: encoder)
    }
  }
}

enum ControllerPresentationRoute {
  static let path = "/api/controller/presentation"

  static func get(
    bridgeService: ControllerBridgeService,
    courseID: String,
    requestID: String
  ) async -> AuthenticationRouteResponse<ControllerPresentationRouteBody> {
    guard !courseID.isEmpty else {
      return AuthenticationRouteResponse(
        statusCode: 400,
        body: .error(
          AuthenticationErrorPayload(
            error: "invalid_request",
            message: "courseId is required.",
            requestId: requestID
          )
        )
      )
    }

    let result = await bridgeService.loadPresentation(
      courseID: courseID,
      requestID: requestID,
      now: Date()
    )

    guard let manifest = result.value else {
      let statusCode = mapControllerErrorStatus(result.error)
      return AuthenticationRouteResponse(
        statusCode: statusCode,
        body: .error(
          AuthenticationErrorPayload(
            error: "controller_presentation_failed",
            message: "Controller presentation could not be loaded.",
            requestId: requestID
          )
        )
      )
    }

    let payload = ControllerPresentationPayload(
      courseId: manifest.courseID,
      presentationId: manifest.presentationID,
      title: manifest.title,
      aspectRatio: manifest.aspectRatio,
      activeSlideIndex: manifest.activeSlideIndex,
      slideCount: manifest.slideCount,
      slides: manifest.slides.map {
        ControllerPresentationPayload.SlidePayload(
          index: $0.index,
          fileName: $0.fileName,
          htmlURL: $0.htmlURL.absoluteString,
          notes: $0.notes,
          notesSource: $0.notesSource.rawValue,
          title: $0.title
        )
      }
    )

    return AuthenticationRouteResponse(statusCode: 200, body: .presentation(payload))
  }
}

struct ControllerNavigationPayload: Decodable {
  let presentationId: String
  let command: String
  let fromIndex: Int
  let requestId: String
}

struct ControllerNavigationResultPayload: Encodable {
  struct SlidePayload: Encodable {
    let index: Int
    let fileName: String
    let htmlURL: String
    let notes: String
    let notesSource: String
    let title: String?
  }

  let activeSlideIndex: Int
  let slide: SlidePayload
}

enum ControllerNavigationRouteBody: Encodable {
  case navigation(ControllerNavigationResultPayload)
  case error(AuthenticationErrorPayload)

  func encode(to encoder: Encoder) throws {
    switch self {
    case .navigation(let payload):
      try payload.encode(to: encoder)
    case .error(let payload):
      try payload.encode(to: encoder)
    }
  }
}

enum ControllerNavigationRoute {
  static let path = "/api/controller/navigation"

  static func post(
    bridgeService: ControllerBridgeService,
    courseID: String,
    payload: ControllerNavigationPayload,
    requestID: String
  ) async -> AuthenticationRouteResponse<ControllerNavigationRouteBody> {
    guard !courseID.isEmpty else {
      return AuthenticationRouteResponse(
        statusCode: 400,
        body: .error(
          AuthenticationErrorPayload(
            error: "invalid_request",
            message: "courseId is required.",
            requestId: requestID
          )
        )
      )
    }

    guard let commandKind = NavigationCommandKind(rawValue: payload.command) else {
      return AuthenticationRouteResponse(
        statusCode: 400,
        body: .error(
          AuthenticationErrorPayload(
            error: "invalid_request",
            message: "Unsupported navigation command.",
            requestId: requestID
          )
        )
      )
    }

    let navigationCommand: NavigationCommand
    do {
      navigationCommand = try NavigationCommand(
        presentationID: payload.presentationId,
        command: commandKind,
        fromIndex: payload.fromIndex,
        issuedAt: Date(),
        requestID: requestID
      )
    } catch {
      return AuthenticationRouteResponse(
        statusCode: 400,
        body: .error(
          AuthenticationErrorPayload(
            error: "invalid_request",
            message: "Navigation command is invalid.",
            requestId: requestID
          )
        )
      )
    }

    let result = await bridgeService.navigate(
      courseID: courseID,
      command: navigationCommand,
      requestID: requestID,
      now: Date()
    )

    guard let manifest = result.value else {
      let statusCode = mapControllerErrorStatus(result.error)
      return AuthenticationRouteResponse(
        statusCode: statusCode,
        body: .error(
          AuthenticationErrorPayload(
            error: "controller_navigation_failed",
            message: "Controller navigation failed.",
            requestId: requestID
          )
        )
      )
    }

    guard manifest.slides.indices.contains(manifest.activeSlideIndex) else {
      return AuthenticationRouteResponse(
        statusCode: 409,
        body: .error(
          AuthenticationErrorPayload(
            error: "controller_navigation_failed",
            message: "Controller navigation is out of sync.",
            requestId: requestID
          )
        )
      )
    }

    let activeSlide = manifest.slides[manifest.activeSlideIndex]
    let responsePayload = ControllerNavigationResultPayload(
      activeSlideIndex: manifest.activeSlideIndex,
      slide: ControllerNavigationResultPayload.SlidePayload(
        index: activeSlide.index,
        fileName: activeSlide.fileName,
        htmlURL: activeSlide.htmlURL.absoluteString,
        notes: activeSlide.notes,
        notesSource: activeSlide.notesSource.rawValue,
        title: activeSlide.title
      )
    )

    return AuthenticationRouteResponse(statusCode: 200, body: .navigation(responsePayload))
  }
}

enum ControllerSlidesRouteBody: Encodable {
  case html(String)
  case error(AuthenticationErrorPayload)

  func encode(to encoder: Encoder) throws {
    switch self {
    case .html(let html):
      try html.encode(to: encoder)
    case .error(let payload):
      try payload.encode(to: encoder)
    }
  }
}

enum ControllerSlidesRoute {
  static let path = "/api/controller/slides"

  static func fileName(from path: String) -> String? {
    let prefix = "/api/controller/slides/"
    guard path.hasPrefix(prefix) else {
      return nil
    }

    let fileName = String(path.dropFirst(prefix.count))
    guard !fileName.isEmpty, !fileName.contains("/") else {
      return nil
    }
    return fileName
  }

  static func get(
    bridgeService: ControllerBridgeService,
    courseID: String,
    fileName: String,
    requestID: String
  ) async -> AuthenticationRouteResponse<ControllerSlidesRouteBody> {
    guard !courseID.isEmpty else {
      return AuthenticationRouteResponse(
        statusCode: 400,
        body: .error(
          AuthenticationErrorPayload(
            error: "invalid_request",
            message: "courseId is required.",
            requestId: requestID
          )
        )
      )
    }

    let result = await bridgeService.fetchSlideHTML(
      courseID: courseID,
      fileName: fileName,
      requestID: requestID,
      now: Date()
    )

    guard let html = result.value else {
      let statusCode = mapControllerErrorStatus(result.error)
      return AuthenticationRouteResponse(
        statusCode: statusCode,
        body: .error(
          AuthenticationErrorPayload(
            error: "controller_slide_failed",
            message: "Controller slide could not be loaded.",
            requestId: requestID
          )
        )
      )
    }

    return AuthenticationRouteResponse(statusCode: 200, body: .html(html))
  }
}

private func mapControllerErrorStatus(_ error: AuthenticationError?) -> Int {
  guard let error else {
    return 502
  }

  if case let .unsafeFailure(reason) = error,
    reason == "controller_out_of_sync" || reason == "controller_manifest_not_cached"
  {
    return 409
  }

  return 502
}
