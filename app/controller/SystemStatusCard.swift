#if canImport(SwiftUI)
import SwiftUI
#if canImport(GaiaCore)
import GaiaCore
#endif

struct SystemStatusCard: View {
  let metrics: DashboardSystemMetrics

  var body: some View {
    VStack(alignment: .leading, spacing: DashboardDesignTokens.Spacing.lg) {
      Text("System Status")
        .font(.headline)
        .foregroundStyle(DashboardDesignTokens.Colors.textPrimary)

      labeledRow(label: "Version", value: metrics.version)
      labeledRow(label: "Service", value: metrics.serviceStatus.rawValue.capitalized)
      labeledRow(label: "Updated", value: Self.timeFormatter.string(from: metrics.lastUpdatedAt))
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

  private func labeledRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundStyle(DashboardDesignTokens.Colors.textSecondary)
      Spacer()
      Text(value)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(DashboardDesignTokens.Colors.textPrimary)
    }
  }

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
  }()
}
#endif
