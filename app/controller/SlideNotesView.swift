#if canImport(SwiftUI)
import SwiftUI

struct SlideNotesView: View {
  let notes: String

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Notizen")
        .font(.headline)

      ScrollView {
        Text(notes)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .padding(16)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.white.opacity(0.9))
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(Color.black.opacity(0.08), lineWidth: 1)
      )
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.white.opacity(0.65))
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.black.opacity(0.08), lineWidth: 1)
    )
  }
}
#endif
