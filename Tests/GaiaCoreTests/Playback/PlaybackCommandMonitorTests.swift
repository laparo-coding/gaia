import Foundation
import Testing

@testable import GaiaCore

/// Unit tests for `PlaybackCommandMonitor` SSE parsing (Spec 011, T002).
/// Tests the `parseCommand` logic by verifying that SSE `data:` payloads
/// are correctly parsed into `PlaybackSSECommand` cases.
@Suite
struct PlaybackCommandMonitorTests {
  @Test
  func parsePlayCommand() {
    let command = PlaybackCommandMonitor.parseCommandForTesting(
      data: #"{"action":"play"}"#
    )
    guard case .play = command else {
      Issue.record("Expected .play"); return
    }
  }

  @Test
  func parseStopCommand() {
    let command = PlaybackCommandMonitor.parseCommandForTesting(
      data: #"{"action":"stop"}"#
    )
    guard case .stop = command else {
      Issue.record("Expected .stop"); return
    }
  }

  @Test
  func parseSeekCommand() {
    let command = PlaybackCommandMonitor.parseCommandForTesting(
      data: #"{"action":"seek","position":12.5}"#
    )
    guard case .seek(let position) = command else {
      Issue.record("Expected .seek"); return
    }
    #expect(position == 12.5)
  }

  @Test
  func parseChapterBoundaryCommand() {
    let command = PlaybackCommandMonitor.parseCommandForTesting(
      data: #"{"action":"chapter-boundary","chapterId":0,"nextChapterId":1}"#
    )
    guard case .chapterBoundary(let chapterId, let nextChapterId) = command else {
      Issue.record("Expected .chapterBoundary"); return
    }
    #expect(chapterId == 0)
    #expect(nextChapterId == 1)
  }

  @Test
  func parseChapterBoundaryWithoutNextChapterId() {
    let command = PlaybackCommandMonitor.parseCommandForTesting(
      data: #"{"action":"chapter-boundary","chapterId":2}"#
    )
    guard case .chapterBoundary(let chapterId, let nextChapterId) = command else {
      Issue.record("Expected .chapterBoundary"); return
    }
    #expect(chapterId == 2)
    #expect(nextChapterId == nil)
  }

  @Test
  func parseInvalidJsonReturnsNil() {
    let command = PlaybackCommandMonitor.parseCommandForTesting(
      data: "not-json"
    )
    #expect(command == nil)
  }

  @Test
  func parseMissingActionReturnsNil() {
    let command = PlaybackCommandMonitor.parseCommandForTesting(
      data: #"{"foo":"bar"}"#
    )
    #expect(command == nil)
  }

  @Test
  func parseUnknownActionReturnsNil() {
    let command = PlaybackCommandMonitor.parseCommandForTesting(
      data: #"{"action":"unknown"}"#
    )
    #expect(command == nil)
  }

  @Test
  func parseSeekMissingPositionReturnsNil() {
    let command = PlaybackCommandMonitor.parseCommandForTesting(
      data: #"{"action":"seek"}"#
    )
    #expect(command == nil)
  }

  // MARK: - Reconnect Backoff (T020)

  @Test
  func reconnectBackoffSequenceIsCorrect() {
    let backoff = PlaybackCommandMonitor.reconnectBackoffForTesting
    #expect(backoff == [0.5, 1, 2, 5])
  }

  @Test
  func maxReconnectAttemptsIsTen() {
    #expect(PlaybackCommandMonitor.maxReconnectAttemptsForTesting == 10)
  }
}
