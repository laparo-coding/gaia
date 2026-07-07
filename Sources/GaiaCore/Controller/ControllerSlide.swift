import Foundation

public enum ControllerNotesSource: String, Codable, Sendable {
  case placeholder
  case upstream
}

public enum ControllerContentState: String, Codable, Sendable {
  case pending
  case ready
  case failed
}

public struct ControllerSlide: Equatable, Sendable {
  public struct Metadata: Equatable, Sendable {
    public let courseID: String?
    public let presentationID: String?
    public let title: String?
    public let etag: String?

    public init(
      courseID: String? = nil,
      presentationID: String? = nil,
      title: String? = nil,
      etag: String? = nil
    ) {
      self.courseID = courseID
      self.presentationID = presentationID
      self.title = title
      self.etag = etag
    }
  }

  public let index: Int
  public let fileName: String
  public let htmlURL: URL
  public let courseID: String?
  public let presentationID: String?
  public let notes: String
  public let notesSource: ControllerNotesSource
  public let title: String?
  public let contentState: ControllerContentState
  public let etag: String?

  public init(
    index: Int,
    fileName: String,
    htmlURL: URL,
    notes: String,
    notesSource: ControllerNotesSource,
    contentState: ControllerContentState,
    metadata: Metadata = Metadata()
  ) throws {
    guard fileName.hasSuffix(".html") else {
      throw ControllerDomainError.invalidFileName(fileName)
    }

    guard !notes.isEmpty else {
      throw ControllerDomainError.emptyNotes
    }

    self.index = index
    self.fileName = fileName
    self.htmlURL = htmlURL
    self.courseID = metadata.courseID
    self.presentationID = metadata.presentationID
    self.notes = notes
    self.notesSource = notesSource
    self.title = metadata.title
    self.contentState = contentState
    self.etag = metadata.etag
  }
}

public enum NavigationCommandKind: String, Codable, Sendable {
  case previous
  case next
}

public struct NavigationCommand: Equatable, Sendable {
  public let presentationID: String
  public let command: NavigationCommandKind
  public let fromIndex: Int
  public let issuedAt: Date
  public let requestID: String

  public init(
    presentationID: String,
    command: NavigationCommandKind,
    fromIndex: Int,
    issuedAt: Date,
    requestID: String
  ) throws {
    guard fromIndex >= 0 else {
      throw ControllerDomainError.invalidNavigationIndex(fromIndex)
    }

    guard !presentationID.isEmpty else {
      throw ControllerDomainError.missingPresentationID
    }

    self.presentationID = presentationID
    self.command = command
    self.fromIndex = fromIndex
    self.issuedAt = issuedAt
    self.requestID = requestID
  }
}

public enum ControllerNavigationPlacement: String, Sendable {
  case belowViewport
}

public enum ControllerOrientation: String, Sendable {
  case landscapeOnly
}

public struct ViewportLayout: Equatable, Sendable {
  public let maxWidthFraction: Double
  public let aspectRatio: String
  public let notesScrollEnabled: Bool
  public let navigationPlacement: ControllerNavigationPlacement
  public let orientation: ControllerOrientation

  public init(
    maxWidthFraction: Double = 0.75,
    aspectRatio: String = "16:9",
    notesScrollEnabled: Bool = true,
    navigationPlacement: ControllerNavigationPlacement = .belowViewport,
    orientation: ControllerOrientation = .landscapeOnly
  ) throws {
    guard maxWidthFraction > 0 && maxWidthFraction <= 0.75 else {
      throw ControllerDomainError.invalidWidthFraction(maxWidthFraction)
    }

    guard aspectRatio == "16:9" else {
      throw ControllerDomainError.invalidAspectRatio(aspectRatio)
    }

    self.maxWidthFraction = maxWidthFraction
    self.aspectRatio = aspectRatio
    self.notesScrollEnabled = notesScrollEnabled
    self.navigationPlacement = navigationPlacement
    self.orientation = orientation
  }
}
