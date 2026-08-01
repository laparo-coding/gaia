import Foundation
import Testing

@testable import GaiaCore

/// Unit tests for `ChapterSummary`, `ChapterListResponse`, and
/// `ChapterRegenerationResult` decoding + validation (Spec 010, FR-003).
@Suite
struct ChapterManifestTests {
  @Test
  func decodesChapterListResponse() throws {
    let json = """
      {
        "assetId": "rec_2026-07-13T10-30-00Z",
        "chapters": [
          { "id": 0, "start": 5.0, "end": 20.0, "title": "Chapter 1" },
          { "id": 1, "start": 20.0, "end": 45.0, "title": "Chapter 2" }
        ]
      }
      """.data(using: .utf8)!

    let response = try JSONDecoder().decode(ChapterListResponse.self, from: json)
    #expect(response.assetId == "rec_2026-07-13T10-30-00Z")
    #expect(response.chapters.count == 2)
    #expect(response.chapters[0].id == 0)
    #expect(response.chapters[0].start == 5.0)
    #expect(response.chapters[0].end == 20.0)
    #expect(response.chapters[0].title == "Chapter 1")
    #expect(response.chapters[1].id == 1)
    #expect(response.chapters[1].start == 20.0)
  }

  @Test
  func decodesChapterRegenerationResult() throws {
    let json = """
      {
        "assetId": "rec_2026-07-13T10-30-00Z",
        "muxAssetId": "mux_chapters_rec_2026-07-13T10-30-00Z",
        "chapterCount": 5
      }
      """.data(using: .utf8)!

    let result = try JSONDecoder().decode(ChapterRegenerationResult.self, from: json)
    #expect(result.assetId == "rec_2026-07-13T10-30-00Z")
    #expect(result.muxAssetId == "mux_chapters_rec_2026-07-13T10-30-00Z")
    #expect(result.chapterCount == 5)
  }

  @Test
  func validationRejectsStartNotLessThanEnd() {
    #expect(throws: ChapterManifestValidationError.startMustBeLessThanEnd) {
      try ChapterSummary(id: 0, start: 20.0, end: 20.0, title: "Zero-length")
    }
    #expect(throws: ChapterManifestValidationError.startMustBeLessThanEnd) {
      try ChapterSummary(id: 0, start: 30.0, end: 20.0, title: "Inverted")
    }
  }

  @Test
  func validationRejectsNonMonotonicIds() {
    #expect(throws: ChapterManifestValidationError.idsMustBeMonotonic) {
      try ChapterListResponse(
        assetId: "rec_test",
        chapters: [
          try ChapterSummary(id: 1, start: 0.0, end: 10.0, title: "B"),
          try ChapterSummary(id: 0, start: 10.0, end: 20.0, title: "A"),
        ])
    }
  }

  @Test
  func validationRejectsOverlappingChapters() {
    #expect(throws: ChapterManifestValidationError.chaptersMustNotOverlap) {
      try ChapterListResponse(
        assetId: "rec_test",
        chapters: [
          try ChapterSummary(id: 0, start: 0.0, end: 15.0, title: "A"),
          try ChapterSummary(id: 1, start: 10.0, end: 20.0, title: "B"),
        ])
    }
  }

  @Test
  func validationRejectsEmptyChapterList() {
    #expect(throws: ChapterManifestValidationError.chaptersMustNotBeEmpty) {
      try ChapterListResponse(assetId: "rec_test", chapters: [])
    }
  }

  @Test
  func validationAcceptsSingleChapter() throws {
    let response = try ChapterListResponse(
      assetId: "rec_test",
      chapters: [try ChapterSummary(id: 0, start: 0.0, end: 60.0, title: "Only")])
    #expect(response.chapters.count == 1)
  }

  @Test
  func validationAcceptsAdjacentChapters() throws {
    // Chapter end == next chapter start is allowed (no gap, no overlap).
    let response = try ChapterListResponse(
      assetId: "rec_test",
      chapters: [
        try ChapterSummary(id: 0, start: 0.0, end: 10.0, title: "A"),
        try ChapterSummary(id: 1, start: 10.0, end: 20.0, title: "B"),
      ])
    #expect(response.chapters.count == 2)
  }
}
