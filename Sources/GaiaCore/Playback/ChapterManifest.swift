import Foundation

/// Validation errors for chapter manifest entities (Spec 010, data-model.md).
public enum ChapterManifestValidationError: Error, Equatable, Sendable {
  case startMustBeLessThanEnd
  case startMustNotBeNegative
  case idsMustBeMonotonic
  case chaptersMustNotOverlap
  case chaptersMustNotBeEmpty
}

/// A single chapter boundary sourced from Aither's
/// `GET /api/recording/chapters/[id]` (seconds-based, Spec 010 FR-003).
public struct ChapterSummary: Equatable, Sendable {
  public let id: Int
  public let start: Double
  public let end: Double
  public let title: String

  public init(id: Int, start: Double, end: Double, title: String) throws {
    guard start >= 0 else {
      throw ChapterManifestValidationError.startMustNotBeNegative
    }
    guard start < end else {
      throw ChapterManifestValidationError.startMustBeLessThanEnd
    }
    self.id = id
    self.start = start
    self.end = end
    self.title = title
  }
}

extension ChapterSummary: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let id = try container.decode(Int.self, forKey: .id)
    let start = try container.decode(Double.self, forKey: .start)
    let end = try container.decode(Double.self, forKey: .end)
    let title = try container.decode(String.self, forKey: .title)
    try self.init(id: id, start: start, end: end, title: title)
  }

  private enum CodingKeys: String, CodingKey {
    case id, start, end, title
  }
}

/// Response from `GET /api/recording/chapters/[id]` (Spec 010 FR-003).
public struct ChapterListResponse: Equatable, Sendable {
  public let assetId: String
  public let chapters: [ChapterSummary]

  public init(assetId: String, chapters: [ChapterSummary]) throws {
    guard !chapters.isEmpty else {
      throw ChapterManifestValidationError.chaptersMustNotBeEmpty
    }
    // Validate monotonic ids.
    for index in 1..<chapters.count {
      if chapters[index].id <= chapters[index - 1].id {
        throw ChapterManifestValidationError.idsMustBeMonotonic
      }
    }
    // Validate no overlaps (adjacent end == next start is allowed).
    for index in 1..<chapters.count {
      if chapters[index].start < chapters[index - 1].end {
        throw ChapterManifestValidationError.chaptersMustNotOverlap
      }
    }
    self.assetId = assetId
    self.chapters = chapters
  }
}

extension ChapterListResponse: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let assetId = try container.decode(String.self, forKey: .assetId)
    let chapters = try container.decode([ChapterSummary].self, forKey: .chapters)
    try self.init(assetId: assetId, chapters: chapters)
  }

  private enum CodingKeys: String, CodingKey {
    case assetId, chapters
  }
}

/// Result of a chapter-regeneration request (Spec 010 FR-005).
///
/// Returned by ``PlaybackClient/regenerate(assetId:requestID:now:)`` after
/// Aither re-encodes chapter metadata for a recording.
public struct ChapterRegenerationResult: Equatable, Sendable {
  /// The original recording / asset identifier.
  public let assetId: String

  /// The Mux asset identifier produced by the regeneration pipeline.
  public let muxAssetId: String

  /// Total number of chapters in the regenerated manifest.
  public let chapterCount: Int

  /// Creates a new regeneration result.
  ///
  /// - Parameters:
  ///   - assetId: The original recording identifier.
  ///   - muxAssetId: The Mux asset identifier. Must not be empty; an empty
  ///     value throws ``ChapterManifestValidationError/chaptersMustNotBeEmpty``.
  ///   - chapterCount: The number of chapters. Must be positive; a non-positive
  ///     value throws ``ChapterManifestValidationError/chaptersMustNotBeEmpty``.
  /// - Throws: ``ChapterManifestValidationError/chaptersMustNotBeEmpty`` if
  ///   `muxAssetId` is empty or `chapterCount` is not positive.
  public init(assetId: String, muxAssetId: String, chapterCount: Int) throws {
    guard !muxAssetId.isEmpty else {
      throw ChapterManifestValidationError.chaptersMustNotBeEmpty
    }
    guard chapterCount > 0 else {
      throw ChapterManifestValidationError.chaptersMustNotBeEmpty
    }
    self.assetId = assetId
    self.muxAssetId = muxAssetId
    self.chapterCount = chapterCount
  }
}

extension ChapterRegenerationResult: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let assetId = try container.decode(String.self, forKey: .assetId)
    let muxAssetId = try container.decode(String.self, forKey: .muxAssetId)
    let chapterCount = try container.decode(Int.self, forKey: .chapterCount)
    try self.init(assetId: assetId, muxAssetId: muxAssetId, chapterCount: chapterCount)
  }

  private enum CodingKeys: String, CodingKey {
    case assetId, muxAssetId, chapterCount
  }
}
