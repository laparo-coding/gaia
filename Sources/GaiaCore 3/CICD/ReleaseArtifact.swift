import Foundation

public struct ReleaseArtifact: Equatable {
  public let releaseId: String
  public let commitSha: String
  public let ipaPath: String
  public let symbolsPath: String
  public let metadataPath: String
  public let tag: String
  public let createdAt: Date

  public init(
    releaseId: String,
    commitSha: String,
    ipaPath: String,
    symbolsPath: String,
    metadataPath: String,
    tag: String,
    createdAt: Date = Date()
  ) {
    self.releaseId = releaseId
    self.commitSha = commitSha
    self.ipaPath = ipaPath
    self.symbolsPath = symbolsPath
    self.metadataPath = metadataPath
    self.tag = tag
    self.createdAt = createdAt
  }

  public var hasAllArtifactPaths: Bool {
    !ipaPath.isEmpty && !symbolsPath.isEmpty && !metadataPath.isEmpty
  }

  public var hasValidSemverTag: Bool {
    SemverTagValidator.isValid(tag)
  }
}

enum SemverTagValidator {
  static func isValid(_ value: String) -> Bool {
    guard value.hasPrefix("v") else {
      return false
    }

    let core = String(value.dropFirst())
    let parts = core.split(separator: ".")

    guard parts.count == 3 else {
      return false
    }

    return parts.allSatisfy { part in
      !part.isEmpty && part.allSatisfy(\.isNumber)
    }
  }
}
