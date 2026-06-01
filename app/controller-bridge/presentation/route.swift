import Foundation
import GaiaCore

struct ControllerPresentationPayload: Codable, Equatable {
  struct SlidePayload: Codable, Equatable {
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

enum ControllerPresentationRoute {
  static let path = "/api/controller/presentation"

  static func get(
    bridgeService: ControllerBridgeService,
    courseID: String,
    requestID: String
  ) async -> AuthenticationRouteResponse<ControllerPresentationPayload> {
    let result = await bridgeService.loadPresentation(
      courseID: courseID,
      requestID: requestID,
      now: Date()
    )

    guard let manifest = result.value else {
      return AuthenticationRouteResponse(statusCode: 502, body: nil)
    }

    return AuthenticationRouteResponse(
      statusCode: 200,
      body: ControllerPresentationPayload(
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
    )
  }
}
