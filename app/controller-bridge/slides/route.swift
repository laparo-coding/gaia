import Foundation
import GaiaCore

enum ControllerSlidesRoute {
  static let path = "/api/controller/slides"

  static func get(
    bridgeService: ControllerBridgeService,
    courseID: String,
    fileName: String,
    requestID: String
  ) async -> AuthenticationRouteResponse<String> {
    let decodedFileName = fileName.removingPercentEncoding ?? fileName

    guard !courseID.isEmpty,
      !requestID.isEmpty,
      decodedFileName.hasSuffix(".html"),
      !decodedFileName.contains(".."),
      !decodedFileName.contains("/"),
      !decodedFileName.contains("\\")
    else {
      return AuthenticationRouteResponse(statusCode: 400, body: nil)
    }

    let result = await bridgeService.fetchSlideHTML(
      courseID: courseID,
      fileName: decodedFileName,
      requestID: requestID,
      now: Date()
    )

    guard let html = result.value else {
      return AuthenticationRouteResponse(statusCode: 502, body: nil)
    }

    return AuthenticationRouteResponse(statusCode: 200, body: html)
  }
}