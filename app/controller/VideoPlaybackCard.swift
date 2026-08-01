#if canImport(SwiftUI)
import AVKit
import GaiaCore
import SwiftUI

/// Video playback card (Spec 010, FR-001 + FR-002 + FR-004a + FR-005).
///
/// Combines the MUX HLS player (`AVPlayer` via `VideoPlayerView`), the
/// "Next Chapter" button, and the "Regenerate chapters" control. Wired to
/// `VideoPlayerViewModel` which uses `PlaybackClient` (Spec 005 Bearer auth).
struct VideoPlaybackCard: View {
  @StateObject private var viewModel: VideoPlayerViewModel
  @State private var assetId: String = "rec_2026-07-13T10-30-00Z"
  @State private var requestID: String = "playback-\(UUID().uuidString)"

  init(playbackClient: PlaybackClient, assetId: String) {
    _assetId = State(initialValue: assetId)
    _viewModel = StateObject(
      wrappedValue: VideoPlayerViewModel(
        playbackClient: playbackClient, assetId: assetId))
  }

  var body: some View {
    VStack(spacing: 16) {
      header

      playerSurface

      NextChapterButton(viewModel: viewModel) {
        viewModel.seekToNextChapter()
      }

      regenerateControl

      if let error = viewModel.regenerationError {
        failureOverlay(error: error)
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.white.opacity(0.82))
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.black.opacity(0.08), lineWidth: 1)
    )
    .task {
      await viewModel.loadChapters(requestID: requestID)
      guard case .ready = viewModel.state else { return }
      await viewModel.preparePlayer(requestID: requestID + "-stream")
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Video-Wiedergabe")
          .font(.caption)
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Text("Kapitel \(currentChapterLabel)")
          .font(.title2.weight(.semibold))
      }
      Spacer()
      Text(String(format: "%.1fs", viewModel.currentPosition))
        .font(.headline.monospacedDigit())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.06))
        .clipShape(Capsule())
    }
  }

  private var currentChapterLabel: String {
    let current = viewModel.chapters.last { $0.start <= viewModel.currentPosition }
    if let current = current {
      return "\(current.id + 1): \(current.title)"
    }
    return "—"
  }

  @ViewBuilder
  private var playerSurface: some View {
    switch viewModel.state {
    case .unloaded, .loadingChapters, .regenerating:
      ProgressView("Lädt…")
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    case .chaptersNotGenerated:
      VStack(spacing: 12) {
        Image(systemName: "exclamationmark.triangle")
          .font(.largeTitle)
          .foregroundStyle(.orange)
        Text("Keine Kapitel verfügbar")
          .font(.headline)
        Text("Drücke „Kapitel regenerieren“, um die Kapitel-Metadaten zu erzeugen.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity, minHeight: 220)
      .background(Color.black.opacity(0.04))
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    case .failed(let error):
      VStack(spacing: 12) {
        Image(systemName: "xmark.octagon")
          .font(.largeTitle)
          .foregroundStyle(.red)
        Text(error.localizedMessage)
          .font(.subheadline)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity, minHeight: 220)
      .background(Color.black.opacity(0.04))
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    case .ready, .playing:
      VideoPlayerView(player: viewModel.player)
        .frame(maxWidth: .infinity, minHeight: 220)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
    }
  }

  private var regenerateControl: some View {
    Button {
      Task {
        await viewModel.regenerate(requestID: requestID + "-regen")
      }
    } label: {
      Label("Kapitel regenerieren", systemImage: "arrow.clockwise")
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(!viewModel.isRegenerateEnabled)
    .opacity(viewModel.isRegenerateEnabled ? 1 : 0.6)
    .accessibilityLabel("Kapitel regenerieren")
  }

  @ViewBuilder
  private func failureOverlay(error: PlaybackError) -> some View {
    if error.isRetryable {
      VStack(spacing: 8) {
        Text(error.localizedMessage)
          .font(.caption)
          .foregroundStyle(.red)
        Button("Erneut versuchen") {
          Task {
            await viewModel.regenerate(requestID: requestID + "-retry")
          }
        }
        .font(.caption.weight(.semibold))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.red.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
  }
}
#endif
