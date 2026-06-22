#if canImport(SwiftUI)
import SwiftUI

struct ControllerRootView: View {
  @StateObject private var dashboardViewModel = DashboardViewModel()
  @StateObject private var viewModel = ControllerViewModel()
  @State private var isPresentingSlides = false

  var body: some View {
    Group {
      if isPresentingSlides {
        presentationView
      } else {
        DashboardRootView(viewModel: dashboardViewModel) {
          Task {
            viewModel.setCourseID(dashboardViewModel.snapshot.course.id)
            await viewModel.loadInitialPresentation()
            isPresentingSlides = true
          }
        }
        .task {
          await dashboardViewModel.loadDashboard()
        }
      }
    }
  }

  private var presentationView: some View {
    GeometryReader { proxy in
      let isWide = proxy.size.width >= proxy.size.height
      let horizontalPadding: CGFloat = 48
      let columnSpacing: CGFloat = 20
      let availableWidth = max(proxy.size.width - horizontalPadding, 0)
      let contentWidth = max(availableWidth - columnSpacing, 0)
      let slidePanelWidth = contentWidth * 0.75
      let notesPanelWidth = contentWidth * 0.25

      Group {
        if isWide {
          HStack(spacing: 20) {
            slidePanel
              .frame(width: slidePanelWidth)

            SlideNotesView(notes: viewModel.currentNotes)
              .frame(width: notesPanelWidth)
          }
        } else {
          VStack(spacing: 20) {
            slidePanel

            SlideNotesView(notes: viewModel.currentNotes)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(
      LinearGradient(
        colors: [Color(red: 0.96, green: 0.97, blue: 0.99), Color(red: 0.90, green: 0.93, blue: 0.97)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(alignment: .top) {
      ControllerStatusOverlay(status: viewModel.status)
        .padding(.top, 18)
    }
  }

  private var slidePanel: some View {
    VStack(spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Gaia-Controller")
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)

          Text(viewModel.currentSlideTitle)
            .font(.title2.weight(.semibold))
            .lineLimit(2)
        }

        Spacer()

        Text(viewModel.slidePositionText)
          .font(.headline.monospacedDigit())
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color.black.opacity(0.06))
          .clipShape(Capsule())
      }

      SlideViewportView(htmlContent: viewModel.currentSlideHTML)
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)

      HStack(spacing: 12) {
        controllerButton(title: "Zurück", command: .previous)
        controllerButton(title: "Weiter", command: .next)
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
  }

  private func controllerButton(title: String, command: ControllerViewModel.NavigationCommandKind) -> some View {
    Button(title) {
      Task {
        await viewModel.navigate(command: command)
      }
    }
    .font(.headline)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(command == .next ? Color.accentColor : Color.black.opacity(0.08))
    .foregroundStyle(command == .next ? Color.white : Color.primary)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .disabled(viewModel.status == .loading)
    .opacity(viewModel.status == .loading ? 0.6 : 1)
  }
}
#endif
