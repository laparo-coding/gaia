import Foundation
import GaiaCore

struct ControllerNavigationPayload: Codable, Equatable {
  let presentationId: String
  let command: String
  let fromIndex: Int
  let requestId: String
}

struct ControllerNavigationResultPayload: Codable, Equatable {
  struct SlidePayload: Codable, Equatable {
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

enum ControllerNavigationRoute {
  static let path = "/api/controller/navigation"

  static func post(
    bridgeService: ControllerBridgeService,
    courseID: String,
    payload: ControllerNavigationPayload
  ) async -> AuthenticationRouteResponse<ControllerNavigationResultPayload> {
    guard !courseID.isEmpty,
      !payload.presentationId.isEmpty,
      !payload.requestId.isEmpty,
      payload.fromIndex >= 0
    else {
      return AuthenticationRouteResponse(statusCode: 400, body: nil)
    }

    guard let commandKind = NavigationCommandKind(rawValue: payload.command) else {
      return AuthenticationRouteResponse(statusCode: 400, body: nil)
    }

    let navigationCommand: NavigationCommand
    do {
      navigationCommand = try NavigationCommand(
        presentationID: payload.presentationId,
        command: commandKind,
        fromIndex: payload.fromIndex,
        issuedAt: Date(),
        requestID: payload.requestId
      )
    } catch {
      return AuthenticationRouteResponse(statusCode: 400, body: nil)
    }

    let result = await bridgeService.navigate(
      courseID: courseID,
      command: navigationCommand,
      requestID: payload.requestId,
      now: Date()
    )

    guard let manifest = result.value else {
      return AuthenticationRouteResponse(statusCode: 502, body: nil)
    }

    let activeSlide = manifest.slides[manifest.activeSlideIndex]

    return AuthenticationRouteResponse(
      statusCode: 200,
      body: ControllerNavigationResultPayload(
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
    )
  }
}
