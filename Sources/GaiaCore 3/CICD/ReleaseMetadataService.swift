import Foundation

public struct ReleaseMetadataService: Sendable {
  public struct Metadata: Codable, Equatable, Sendable {
    public let releaseId: String
    public let tag: String
    public let commitSha: String
    public let createdAt: Date

    public init(releaseId: String, tag: String, commitSha: String, createdAt: Date = Date()) {
      self.releaseId = releaseId
      self.tag = tag
      self.commitSha = commitSha
      self.createdAt = createdAt
    }
  }

  public init() {}

  public func makeMetadata(
    releaseId: String,
    tag: String,
    commitSha: String
  ) -> Metadata {
    Metadata(releaseId: releaseId, tag: tag, commitSha: commitSha)
  }

  public func encode(_ metadata: Metadata) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(metadata)
  }
}
