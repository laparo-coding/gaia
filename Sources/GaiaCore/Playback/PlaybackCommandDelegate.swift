import Foundation

/// Delegate protocol for receiving playback commands from Aither's SSE channel.
///
/// The `PlaybackCommandMonitor` calls these methods on the main actor via
/// `Task { @MainActor in ... }` per SSE event (Spec 011, NFR-001).
/// The conformer is typically `VideoPlayerViewModel`.
@MainActor
public protocol PlaybackCommandDelegate: AnyObject {
  /// Called when a `play` SSE command is received.
  func onPlay()

  /// Called when a `stop` SSE command is received.
  func onStop()

  /// Called when a `seek` SSE command is received.
  /// - Parameter position: Seek target in seconds.
  func onSeek(position: Double)

  /// Called when a `chapter-boundary` SSE command is received.
  /// Gaia pauses to stay in sync with the Aither web player (Spec 010 FR-015).
  func onChapterBoundary()

  /// Called when the SSE connection is permanently lost (max reconnect
  /// attempts exhausted). The UI should show a "Sync offline" hint.
  func onSyncOffline()
}
