import SwiftUI

struct DiagnosticsView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.dismiss) private var dismiss
  @State private var report: DiagnosticsReport?

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.black.ignoresSafeArea()
      LinearGradient(
        colors: [VelyraTheme.primary.opacity(0.18), .black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
      .accessibilityHidden(true)

      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          Text("diagnostics.title")
            .font(.system(size: 52, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
          Text("diagnostics.body")
            .font(.title3)
            .foregroundStyle(.white.opacity(0.65))

          if let report {
            Text(report.formattedText)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.white.opacity(0.82))
              .padding(28)
              .frame(maxWidth: .infinity, alignment: .leading)
              .velyraGlass(cornerRadius: 26)
              .accessibilityLabel("diagnostics.report")
          } else {
            ProgressView("diagnostics.generating")
              .controlSize(.large)
              .tint(VelyraTheme.primary)
          }

          Text("diagnostics.privacy")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 78)
        .padding(.top, 130)
        .padding(.bottom, 100)
      }

      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark").frame(width: 54, height: 54)
      }
      .buttonStyle(VelyraGlassButtonStyle())
      .padding(.leading, 50)
      .padding(.top, 36)
      .accessibilityLabel("action.close")
    }
    .task { report = await DiagnosticsReportBuilder.build(appState: appState) }
    .onExitCommand { dismiss() }
  }
}
