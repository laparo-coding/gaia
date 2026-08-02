import Foundation
import Testing

@testable import GaiaCore

/// Unit tests for `PlaybackCommandDelegate` protocol conformance (Spec 011, T001).
/// Verifies that a minimal `@MainActor` mock conforming to the protocol
/// receives all callbacks.
@Suite
struct PlaybackCommandDelegateTests {
  @Test
  @MainActor
  func mockReceivesOnPlay() async {
    let mock = MockPlaybackDelegate()
    mock.onPlay()
    #expect(mock.playCallCount == 1)
  }

  @Test
  @MainActor
  func mockReceivesOnStop() async {
    let mock = MockPlaybackDelegate()
    mock.onStop()
    #expect(mock.stopCallCount == 1)
  }

  @Test
  @MainActor
  func mockReceivesOnSeek() async {
    let mock = MockPlaybackDelegate()
    mock.onSeek(position: 12.5)
    #expect(mock.seekCallCount == 1)
    #expect(mock.lastSeekPosition == 12.5)
  }

  @Test
  @MainActor
  func mockReceivesOnChapterBoundary() async {
    let mock = MockPlaybackDelegate()
    mock.onChapterBoundary()
    #expect(mock.chapterBoundaryCallCount == 1)
  }

  @Test
  @MainActor
  func mockReceivesOnSyncOffline() async {
    let mock = MockPlaybackDelegate()
    mock.onSyncOffline()
    #expect(mock.syncOfflineCallCount == 1)
  }

  @Test
  @MainActor
  func multipleCallsAccumulate() async {
    let mock = MockPlaybackDelegate()
    mock.onPlay()
    mock.onPlay()
    mock.onStop()
    #expect(mock.playCallCount == 2)
    #expect(mock.stopCallCount == 1)
  }
}

// MARK: - Mock

@MainActor
final class MockPlaybackDelegate: PlaybackCommandDelegate {
  var playCallCount = 0
  var stopCallCount = 0
  var seekCallCount = 0
  var lastSeekPosition: Double?
  var chapterBoundaryCallCount = 0
  var syncOfflineCallCount = 0

  func onPlay() { playCallCount += 1 }
  func onStop() { stopCallCount += 1 }
  func onSeek(position: Double) {
    seekCallCount += 1
    lastSeekPosition = position
  }
  func onChapterBoundary() { chapterBoundaryCallCount += 1 }
  func onSyncOffline() { syncOfflineCallCount += 1 }
}
