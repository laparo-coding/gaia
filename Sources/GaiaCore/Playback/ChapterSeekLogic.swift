import Foundation

/// Pure, side-effect-free chapter seek logic (Spec 010, FR-002 + FR-004).
///
/// Given the loaded chapter list and the current playback position (seconds),
/// returns the next chapter whose `start` is greater than the current position,
/// or `nil` when the position is within (or past) the last chapter.
///
/// This is a pure function — fully testable without a player or UI. The
/// `VideoPlayerViewModel` calls this on every position update to recompute the
/// "Next Chapter" button's enabled state, and on button press to determine the
/// seek target.
public enum ChapterSeekLogic {
  /// Returns the first chapter whose `start` exceeds `currentPosition`, or
  /// `nil` if no such chapter exists (FR-002, FR-004).
  ///
  /// - Parameters:
  ///   - chapters: Ordered list of chapter summaries (may be empty).
  ///   - currentPosition: Current playback position in seconds.
  /// - Returns: The next chapter to seek to, or `nil` if in/past the last
  ///   chapter.
  public static func nextChapter(
    chapters: [ChapterSummary],
    currentPosition: Double
  ) -> ChapterSummary? {
    chapters.first { $0.start > currentPosition }
  }
}
