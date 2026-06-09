#if canImport(SwiftUI)
import SwiftUI
#if canImport(GaiaCore)
import GaiaCore
#endif

struct DashboardRootView: View {
  @ObservedObject var viewModel: DashboardViewModel
  let startSeminar: () -> Void

  var body: some View {
    VStack(spacing: DashboardDesignTokens.Spacing.xl) {
      header

      if let warning = viewModel.snapshot.warningMessage {
        Text(warning)
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, DashboardDesignTokens.Spacing.lg)
          .padding(.vertical, DashboardDesignTokens.Spacing.sm)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(DashboardDesignTokens.Colors.degraded.opacity(0.18))
          .clipShape(RoundedRectangle(cornerRadius: DashboardDesignTokens.CornerRadius.inner, style: .continuous))
      }

      cardGrid

      Spacer(minLength: 0)
    }
    .padding(DashboardDesignTokens.Spacing.xxl)
    .background(DashboardDesignTokens.Colors.background)
  }

  private var header: some View {
    HStack(spacing: DashboardDesignTokens.Spacing.lg) {
      VStack(alignment: .leading, spacing: DashboardDesignTokens.Spacing.xs) {
        Text("Gaia")
          .font(.caption)
          .foregroundStyle(DashboardDesignTokens.Colors.textSecondary)
          .textCase(.uppercase)

        Text(viewModel.snapshot.course.title)
          .font(.title2.weight(.bold))
          .foregroundStyle(DashboardDesignTokens.Colors.textPrimary)
      }

      Spacer()

      Button("Seminar starten") {
        startSeminar()
      }
      .font(.headline)
      .padding(.horizontal, DashboardDesignTokens.Spacing.xl)
      .padding(.vertical, DashboardDesignTokens.Spacing.md)
      .background(viewModel.canStartSeminar ? DashboardDesignTokens.Colors.accent : Color.gray.opacity(0.35))
      .foregroundStyle(Color.white)
      .clipShape(RoundedRectangle(cornerRadius: DashboardDesignTokens.CornerRadius.inner, style: .continuous))
      .disabled(!viewModel.canStartSeminar)
      .opacity(viewModel.canStartSeminar ? 1 : 0.6)
    }
  }

  private var cardGrid: some View {
    VStack(spacing: DashboardDesignTokens.Spacing.lg) {
      ConnectionMonitorCard(connection: viewModel.snapshot.connection)
      ParticipantOverviewCard(participants: viewModel.snapshot.participants)
      SystemStatusCard(metrics: viewModel.snapshot.system)
    }
  }
}
#endif
