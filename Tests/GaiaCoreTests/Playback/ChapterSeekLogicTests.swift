import Foundation
import Testing

@testable import GaiaCore

/// Pure unit tests for `ChapterSeekLogic.nextChapter(chapters:currentPosition:)`
/// (Spec 010, FR-002 + FR-004). No UI, no player, no network — fully deterministic.
@Suite
struct ChapterSeekLogicTests {
  @Test
  func returnsFirstChapterWithStartGreaterThanCurrentPosition() throws {
    let chapters: [ChapterSummary] = [
      try ChapterSummary(id: 0, start: 5.0, end: 20.0, title: "Chapter 1"),
      try ChapterSummary(id: 1, start: 20.0, end: 45.0, title: "Chapter 2"),
      try ChapterSummary(id: 2, start: 45.0, end: 90.0, title: "Chapter 3"),
    ]

    // Mid-chapter (position 12.0 in chapter 0): next is chapter 1.
    let next = ChapterSeekLogic.nextChapter(chapters: chapters, currentPosition: 12.0)
    let unwrapped = try #require(next)
    #expect(unwrapped.id == 1)
    #expect(unwrapped.start == 20.0)
  }

  @Test
  func atChapterBoundaryReturnsNextChapter() throws {
    let chapters: [ChapterSummary] = [
      try ChapterSummary(id: 0, start: 5.0, end: 20.0, title: "Chapter 1"),
      try ChapterSummary(id: 1, start: 20.0, end: 45.0, title: "Chapter 2"),
    ]

    // Paused just before chapter 1 start (19.999): next is chapter 1.
    // At exactly 20.0 (chapter 1 start), there is no chapter with start > 20.0
    // in this 2-chapter list, so the button would be disabled — consistent with
    // FR-002's strict "start > currentPosition" rule.
    let next = ChapterSeekLogic.nextChapter(chapters: chapters, currentPosition: 19.999)
    let unwrapped = try #require(next)
    #expect(unwrapped.id == 1)
  }

  @Test
  func inLastChapterReturnsNil() throws {
    let chapters: [ChapterSummary] = [
      try ChapterSummary(id: 0, start: 5.0, end: 20.0, title: "Chapter 1"),
      try ChapterSummary(id: 1, start: 20.0, end: 45.0, title: "Chapter 2"),
    ]

    // Position 30.0 is inside the last chapter (chapter 1): no next chapter.
    #expect(ChapterSeekLogic.nextChapter(chapters: chapters, currentPosition: 30.0) == nil)
  }

  @Test
  func pastLastChapterReturnsNil() throws {
    let chapters: [ChapterSummary] = [
      try ChapterSummary(id: 0, start: 5.0, end: 20.0, title: "Chapter 1"),
      try ChapterSummary(id: 1, start: 20.0, end: 45.0, title: "Chapter 2"),
    ]

    // Position 100.0 is past the last chapter: no next chapter.
    #expect(ChapterSeekLogic.nextChapter(chapters: chapters, currentPosition: 100.0) == nil)
  }

  @Test
  func emptyChaptersReturnsNil() {
    #expect(ChapterSeekLogic.nextChapter(chapters: [], currentPosition: 0.0) == nil)
  }

  @Test
  func singleChapterAlwaysReturnsNil() throws {
    let chapters: [ChapterSummary] = [
      try ChapterSummary(id: 0, start: 0.0, end: 60.0, title: "Only Chapter")
    ]

    // With a single chapter, there is never a "next" chapter.
    #expect(ChapterSeekLogic.nextChapter(chapters: chapters, currentPosition: 10.0) == nil)
    #expect(ChapterSeekLogic.nextChapter(chapters: chapters, currentPosition: 0.0) == nil)
  }

  @Test
  func positionBeforeFirstChapterReturnsFirstChapter() throws {
    let chapters: [ChapterSummary] = [
      try ChapterSummary(id: 0, start: 5.0, end: 20.0, title: "Chapter 1"),
      try ChapterSummary(id: 1, start: 20.0, end: 45.0, title: "Chapter 2"),
    ]

    // Position 0.0 is before the first chapter start (5.0): next is chapter 0.
    let next = ChapterSeekLogic.nextChapter(chapters: chapters, currentPosition: 0.0)
    let unwrapped = try #require(next)
    #expect(unwrapped.id == 0)
  }
}
