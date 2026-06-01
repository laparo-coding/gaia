import Foundation

public enum ControllerSessionStatus: String, Sendable {
  case idle
  case loading
  case ready
  case error
  case unavailable
}

public enum ControllerDomainError: Error, Equatable, Sendable {
  case missingCourseID
  case missingPresentationID
  case invalidAspectRatio(String)
  case invalidSlideCount(expected: Int, actual: Int)
  case invalidActiveSlideIndex(Int)
  case nonSequentialSlideIndexes
  case missingErrorCode
  case invalidFileName(String)
  case emptyNotes
  case invalidWidthFraction(Double)
  case invalidNavigationIndex(Int)
  case unsupportedNavigationCommand(String)
}

public struct ControllerSession: Equatable, Sendable {
  public let sessionID: String
  public let courseID: String?
  public let presentationID: String?
  public let status: ControllerSessionStatus
  public let activeSlideIndex: Int
  public let lastSyncedAt: Date?
  public let lastErrorCode: String?

  public init(
    sessionID: String,
    courseID: String?,
    presentationID: String?,
    status: ControllerSessionStatus,
    activeSlideIndex: Int,
    lastSyncedAt: Date?,
    lastErrorCode: String?
  ) throws {
    if status != .idle {
      guard let courseID, !courseID.isEmpty else {
        throw ControllerDomainError.missingCourseID
      }
      guard let presentationID, !presentationID.isEmpty else {
        throw ControllerDomainError.missingPresentationID
      }
    }

    if status == .error, lastErrorCode?.isEmpty != false {
      throw ControllerDomainError.missingErrorCode
    }

    self.sessionID = sessionID
    self.courseID = courseID
    self.presentationID = presentationID
    self.status = status
    self.activeSlideIndex = activeSlideIndex
    self.lastSyncedAt = lastSyncedAt
    self.lastErrorCode = lastErrorCode
  }

  public func validating(against manifest: ControllerManifest) throws -> ControllerSession {
    guard (0..<manifest.slides.count).contains(activeSlideIndex) else {
      throw ControllerDomainError.invalidActiveSlideIndex(activeSlideIndex)
    }
    return self
  }
}

public struct ControllerManifest: Equatable, Sendable {
  public let courseID: String
  public let presentationID: String
  public let title: String
  public let aspectRatio: String
  public let slideCount: Int
  public let activeSlideIndex: Int
  public let lastUpdated: Date?
  public let slides: [ControllerSlide]

  public init(
    courseID: String,
    presentationID: String,
    title: String,
    aspectRatio: String,
    activeSlideIndex: Int,
    lastUpdated: Date?,
    slides: [ControllerSlide]
  ) throws {
    guard !courseID.isEmpty else {
      throw ControllerDomainError.missingCourseID
    }

    guard !presentationID.isEmpty else {
      throw ControllerDomainError.missingPresentationID
    }

    guard aspectRatio == "16:9" else {
      throw ControllerDomainError.invalidAspectRatio(aspectRatio)
    }

    let expectedIndexes = Array(0..<slides.count)
    let actualIndexes = slides.map(\.index)
    guard expectedIndexes == actualIndexes else {
      throw ControllerDomainError.nonSequentialSlideIndexes
    }

    guard (0..<slides.count).contains(activeSlideIndex) else {
      throw ControllerDomainError.invalidActiveSlideIndex(activeSlideIndex)
    }

    self.courseID = courseID
    self.presentationID = presentationID
    self.title = title
    self.aspectRatio = aspectRatio
    self.slideCount = slides.count
    self.activeSlideIndex = activeSlideIndex
    self.lastUpdated = lastUpdated
    self.slides = slides
  }

  public func replacingActiveSlideIndex(_ newIndex: Int) throws -> ControllerManifest {
    try ControllerManifest(
      courseID: courseID,
      presentationID: presentationID,
      title: title,
      aspectRatio: aspectRatio,
      activeSlideIndex: newIndex,
      lastUpdated: Date(),
      slides: slides
    )
  }
}
