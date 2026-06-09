#if canImport(SwiftUI)
import SwiftUI
#if canImport(GaiaCore)
import GaiaCore
#endif

struct ConnectionMonitorCard: View {
  let connection: DashboardConnectionStatus

  var body: some View {
    VStack(alignment: .leading, spacing: DashboardDesignTokens.Spacing.lg) {
      Text("Connection Monitor")
        .font(.headline)
        .foregroundStyle(DashboardDesignTokens.Colors.textPrimary)

      statusRow(service: "Aither", state: connection.aither)
      statusRow(service: "Hemera", state: connection.hemera)
    }
    .padding(DashboardDesignTokens.Spacing.xl)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DashboardDesignTokens.Colors.surface)
    .clipShape(RoundedRectangle(cornerRadius: DashboardDesignTokens.CornerRadius.card, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: DashboardDesignTokens.CornerRadius.card, style: .continuous)
        .stroke(Color.black.opacity(0.08), lineWidth: 1)
    )
  }

  private func statusRow(service: String, state: DashboardConnectionState) -> some View {
    HStack(spacing: DashboardDesignTokens.Spacing.md) {
      Circle()
        .fill(color(for: state))
        .frame(width: 10, height: 10)

      Text(service)
        .font(.subheadline.weight(.semibold))

      Spacer()

      Text(state.rawValue.capitalized)
        .font(.subheadline.monospaced())
        .padding(.horizontal, DashboardDesignTokens.Spacing.md)
        .padding(.vertical, DashboardDesignTokens.Spacing.xs)
        .background(color(for: state).opacity(0.15))
        .clipShape(Capsule())
    }
  }

  private func color(for state: DashboardConnectionState) -> Color {
    switch state {
    case .connected:
      return DashboardDesignTokens.Colors.healthy
    case .connecting:
      return DashboardDesignTokens.Colors.degraded
    case .disconnected:
      return DashboardDesignTokens.Colors.unavailable
    }
  }
}
#endif
