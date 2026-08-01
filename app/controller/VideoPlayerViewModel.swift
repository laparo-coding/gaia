#if canImport(SwiftUI)
import Combine
import Foundation
import GaiaCore
import SwiftUI

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Player view model for chaptered video playback (Spec 010, FR-001 + FR-002 +
/// FR-004 + FR-004a + FR-005 + FR-007).
///
/// `@MainActor` `ObservableObject` (SwiftUI convention). Owns the `AVPlayer`,
/// observes current playback position via a periodic time observer (research
/// R4), and exposes the "Next Chapter" seek action as a client-side seek
/// (FR-002, NFR-001 ≤ 200 ms).
@MainActor
final class VideoPlayerViewModel: ObservableObject {
  /// Player lifecycle state (data-model.md State Transitions).
  enum State: Equatable {
    case unloaded
    case loadingChapters
    case ready
    case playing
    case chaptersNotGenerated
    case regenerating
    case failed(PlaybackError)
  }

  @Published private(set) var state: State = .unloaded
  @Published private(set) var chapters: [ChapterSummary] = []
  @Published private(set) var currentPosition: Double = 0.0
  @Published private(set) var regenerationError: PlaybackError?

  /// The next chapter to seek to, or `nil` when in/past the last chapter (FR-004)
  /// or when chapters are not available (FR-004a).
  var nextChapter: ChapterSummary? {
    ChapterSeekLogic.nextChapter(chapters: chapters, currentPosition: currentPosition)
  }

  /// Whether the "Next Chapter" button is enabled (FR-002, FR-004, FR-004a).
  var isNextChapterEnabled: Bool {
    switch state {
    case .ready, .playing:
      return nextChapter != nil
    default:
      return false
    }
  }

  /// Whether the "Regenerate chapters" control is enabled (disabled during
  /// active regeneration).
  var isRegenerateEnabled: Bool {
    state != .regenerating && state != .loadingChapters
  }

  private let playbackClient: PlaybackClient
  private let assetId: String
  #if canImport(AVFoundation)
  @Published private(set) var player: AVPlayer?
  private var timeObserver: Any?
  #endif
  private var playbackURL: URL?

  init(playbackClient: PlaybackClient, assetId: String) {
    self.playbackClient = playbackClient
    self.assetId = assetId
  }

  // MARK: - Load (FR-001 + FR-003)

  func loadChapters(requestID: String) async {
    state = .loadingChapters
    regenerationError = nil

    let result = await playbackClient.fetchChapters(
      assetId: assetId, requestID: requestID)

    if let chapterList = result.value {
      chapters = chapterList.chapters
      state = .ready
    } else if let error = result.playbackError {
      if error == .chaptersNotGenerated {
        state = .chaptersNotGenerated
      } else {
        state = .failed(error)
      }
    } else {
      state = .failed(.invalidResponse)
    }
  }

  // MARK: - Playback (FR-001)

  /// Loads the playback URL from Aither's stream endpoint and prepares the
  /// `AVPlayer`. Must be called on the main actor.
  func preparePlayer(requestID: String) async {
    let result = await playbackClient.resolvePlaybackURL(
      assetId: assetId, requestID: requestID)

    guard let url = result.value else {
      state = .failed(result.playbackError ?? .invalidResponse)
      return
    }

    playbackURL = url
    #if canImport(AVFoundation)
    detachTimeObserver()
    let playerItem = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: playerItem)
    self.player = player
    attachTimeObserver(to: player)
    #endif
    state = .ready
  }

  func play() {
    #if canImport(AVFoundation)
    player?.play()
    #endif
    state = .playing
  }

  func pause() {
    #if canImport(AVFoundation)
    player?.pause()
    #endif
    if state == .playing {
      state = .ready
    }
  }

  // MARK: - Next Chapter (FR-002, client-side seek, NFR-001)

  func seekToNextChapter() {
    guard let next = nextChapter else { return }
    #if canImport(AVFoundation)
    let target = CMTime(seconds: next.start, preferredTimescale: 600)
    player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    #endif
    currentPosition = next.start
  }

  // MARK: - Regeneration (FR-005 + FR-006 + FR-007)

  func regenerate(requestID: String) async {
    state = .regenerating
    regenerationError = nil

    let result = await playbackClient.regenerate(
      assetId: assetId, requestID: requestID)

    if result.value != nil {
      // FR-007: refresh both chapters and the playback asset.
      await loadChapters(requestID: requestID + "-refresh")
      guard state == .ready else { return }
      await preparePlayer(requestID: requestID + "-stream-refresh")
    } else if let error = result.playbackError {
      regenerationError = error
      state = .failed(error)
    } else {
      regenerationError = .invalidResponse
      state = .failed(.invalidResponse)
    }
  }

  // MARK: - Position observation (research R4)

  #if canImport(AVFoundation)
  private func detachTimeObserver() {
    if let existing = timeObserver {
      player?.removeTimeObserver(existing)
      timeObserver = nil
    }
  }

  private func attachTimeObserver(to player: AVPlayer) {
    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(
      forInterval: interval, queue: .main
    ) { [weak self] time in
      Task { @MainActor in
        self?.currentPosition = time.seconds
      }
    }
  }
  #endif
}
#endif
