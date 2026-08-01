#if canImport(SwiftUI)
import GaiaCore
import SwiftUI

/// "Next Chapter" button (Spec 010, FR-002 + FR-004 + FR-004a).
///
/// Enabled when the player is ready/playing and a next chapter exists
/// (position-relative seek logic, FR-002). Disabled when in/past the last
/// chapter (FR-004) or when chapters are not generated (FR-004a, with hint).
struct NextChapterButton: View {
  @ObservedObject var viewModel: VideoPlayerViewModel
  let action: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      Button(action: action) {
        Label("Nächstes Kapitel", systemImage: "forward.fill")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(
            viewModel.isNextChapterEnabled
              ? Color.accentColor : Color.black.opacity(0.08)
          )
          .foregroundStyle(
            viewModel.isNextChapterEnabled ? Color.white : Color.primary
          )
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(!viewModel.isNextChapterEnabled)
      .opacity(viewModel.isNextChapterEnabled ? 1 : 0.6)
      .accessibilityLabel("Nächstes Kapitel")

      if case .chaptersNotGenerated = viewModel.state {
        // FR-004a: hint prompting the operator to trigger regeneration first.
        Text("Kapitel noch nicht generiert. Bitte zuerst regenerieren.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
  }
}
#endif
