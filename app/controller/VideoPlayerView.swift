#if canImport(SwiftUI)
import AVKit
import GaiaCore
import SwiftUI

/// SwiftUI wrapper for `AVPlayerViewController` (Spec 010, FR-001).
///
/// Uses native `AVPlayer`/`AVPlayerViewController` (AVFoundation/AVKit) to play
/// the MUX HLS playback URL resolved via Aither's stream endpoint (research R1
/// + R2). No third-party MUX SDK dependency.
///
/// Only available on iOS/iPadOS (AVKit's `AVPlayerViewController` is a UIKit
/// type). On macOS builds (CI/tests), a placeholder is shown instead.
#if os(iOS)
struct VideoPlayerView: UIViewControllerRepresentable {
  let player: AVPlayer?

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = player
    controller.showsPlaybackControls = true
    controller.allowsPictureInPicturePlayback = true
    return controller
  }

  func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
    uiViewController.player = player
  }
}
#else
struct VideoPlayerView: View {
  let player: AVPlayer?

  var body: some View {
    Text("Video-Wiedergabe nur auf iOS/iPadOS verfügbar")
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, minHeight: 220)
      .background(Color.black.opacity(0.04))
  }
}
#endif
#endif
