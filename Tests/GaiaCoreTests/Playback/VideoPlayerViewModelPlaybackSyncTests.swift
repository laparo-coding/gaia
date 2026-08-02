#if canImport(SwiftUI)
import Foundation
import Testing

@testable import GaiaCore

/// Integration tests for `PlaybackCommandDelegate` conformance logic
/// (Spec 011, T010–T012).
///
/// Since `VideoPlayerViewModel` lives in the `GaiaControllerApp` target
/// (not `GaiaCore`), these tests verify the delegate callback logic using
/// a mock that replicates the same `hasPlayedOnce` + initial-seek + pause
/// logic. The actual ViewModel extension is validated via manual E2E.
@Suite
struct VideoPlayerViewModelPlaybackSyncTests {
  @Test
  @MainActor
  func onPlaySeeksToFirstChapterOnFirstCall() async throws {
    let mock = MockPlaybackViewModel()
    mock.chapters = [
      try ChapterSummary(id: 0, start: 5.0, end: 20.0, title: "Ch 1"),
      try ChapterSummary(id: 1, start: 20.0, end: 45.0, title: "Ch 2"),
    ]

    mock.onPlay()

    #expect(mock.hasPlayedOnce == true)
    #expect(mock.isPlaying == true)
    #expect(mock.currentPosition == 5.0)
  }

  @Test
  @MainActor
  func onPlayDoesNotSeekOnSubsequentCalls() async throws {
    let mock = MockPlaybackViewModel()
    mock.chapters = [
      try ChapterSummary(id: 0, start: 5.0, end: 20.0, title: "Ch 1"),
    ]

    mock.onPlay()
    #expect(mock.currentPosition == 5.0)

    mock.currentPosition = 12.0
    mock.onPlay()
    #expect(mock.currentPosition == 12.0)
  }

  @Test
  @MainActor
  func onPlayWithoutChaptersPlaysFromCurrentPosition() async {
    let mock = MockPlaybackViewModel()
    mock.onPlay()

    #expect(mock.hasPlayedOnce == true)
    #expect(mock.isPlaying == true)
    #expect(mock.currentPosition == 0.0)
  }

  @Test
  @MainActor
  func onStopPausesPlayback() async {
    let mock = MockPlaybackViewModel()
    mock.onPlay()
    #expect(mock.isPlaying == true)

    mock.onStop()
    #expect(mock.isPlaying == false)
  }

  @Test
  @MainActor
  func onSeekUpdatesPosition() async {
    let mock = MockPlaybackViewModel()
    mock.onSeek(position: 30.5)
    #expect(mock.currentPosition == 30.5)
  }

  @Test
  @MainActor
  func onChapterBoundaryPausesPlayback() async {
    let mock = MockPlaybackViewModel()
    mock.onPlay()
    #expect(mock.isPlaying == true)

    mock.onChapterBoundary()
    #expect(mock.isPlaying == false)
  }

  @Test
  @MainActor
  func onSyncOfflineSetsState() async {
    let mock = MockPlaybackViewModel()
    #expect(mock.syncOffline == false)

    mock.onSyncOffline()
    #expect(mock.syncOffline == true)
  }
}

// MARK: - Mock ViewModel

/// Mock that replicates the `VideoPlayerViewModel` delegate logic
/// (Spec 011, FR-004 + FR-005 + NFR-003) for testing without the
/// `GaiaControllerApp` target.
@MainActor
final class MockPlaybackViewModel: PlaybackCommandDelegate {
  var chapters: [ChapterSummary] = []
  var currentPosition: Double = 0.0
  var hasPlayedOnce: Bool = false
  var isPlaying: Bool = false
  var syncOffline: Bool = false

  func onPlay() {
    if !hasPlayedOnce && chapters.count > 0 {
      currentPosition = chapters[0].start
    }
    hasPlayedOnce = true
    isPlaying = true
  }

  func onStop() {
    isPlaying = false
  }

  func onSeek(position: Double) {
    currentPosition = position
  }

  func onChapterBoundary() {
    isPlaying = false
  }

  func onSyncOffline() {
    syncOffline = true
  }
}
#endif
