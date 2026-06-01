#if canImport(SwiftUI)
import SwiftUI

struct ControllerStatusOverlay: View {
  let status: ControllerViewModel.Status

  var body: some View {
    switch status {
    case .idle, .ready:
      EmptyView()
    case .loading:
      ProgressView("Lädt")
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    case .failed(let message):
      Text(message)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.15))
    }
  }
}
#endif
