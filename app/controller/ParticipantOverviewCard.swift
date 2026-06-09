#if canImport(SwiftUI)
import SwiftUI
#if canImport(GaiaCore)
import GaiaCore
#endif

struct ParticipantOverviewCard: View {
  let participants: [DashboardParticipant]

  private let columns = [
    GridItem(.flexible(), spacing: DashboardDesignTokens.Spacing.md),
    GridItem(.flexible(), spacing: DashboardDesignTokens.Spacing.md),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: DashboardDesignTokens.Spacing.lg) {
      Text("Participants")
        .font(.headline)
        .foregroundStyle(DashboardDesignTokens.Colors.textPrimary)

      LazyVGrid(columns: columns, spacing: DashboardDesignTokens.Spacing.md) {
        ForEach(participants) { participant in
          HStack(spacing: DashboardDesignTokens.Spacing.sm) {
            Circle()
              .fill(DashboardDesignTokens.Colors.accent.opacity(0.15))
              .frame(width: 34, height: 34)
              .overlay(
                Text(initials(from: participant.displayName))
                  .font(.caption.weight(.bold))
                  .foregroundStyle(DashboardDesignTokens.Colors.accent)
              )

            Text(participant.displayName)
              .font(.subheadline)
              .lineLimit(1)

            Spacer(minLength: 0)
          }
          .padding(DashboardDesignTokens.Spacing.md)
          .background(DashboardDesignTokens.Colors.surfaceMuted)
          .clipShape(RoundedRectangle(cornerRadius: DashboardDesignTokens.CornerRadius.inner, style: .continuous))
        }
      }
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

  private func initials(from name: String) -> String {
    let tokens = name.split(separator: " ")
    if tokens.count >= 2 {
      return "\(tokens[0].prefix(1))\(tokens[1].prefix(1))".uppercased()
    }
    return String(name.prefix(2)).uppercased()
  }
}
#endif
