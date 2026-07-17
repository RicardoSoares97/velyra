import SwiftUI

struct StremioImportView: View {
  let existingURLs: [String]
  let onImport: ([String]) -> Void
  let onClose: () -> Void

  @StateObject private var viewModel = StremioImportViewModel()

  var body: some View {
    ZStack {
      Color(red: 0.02, green: 0.02, blue: 0.03).ignoresSafeArea()

      RadialGradient(
        colors: [VelyraTheme.primary.opacity(0.16), .clear],
        center: .top,
        startRadius: 20,
        endRadius: 1_000
      )
      .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 30) {
        header
        content
      }
      .padding(54)
      .frame(maxWidth: 1_360, maxHeight: 900, alignment: .topLeading)
      .background(
        Color(red: 0.075, green: 0.075, blue: 0.09).opacity(0.97),
        in: RoundedRectangle(cornerRadius: 34, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
          .stroke(.white.opacity(0.12), lineWidth: 1)
      }
    }
    .task {
      viewModel.start(installed: existingURLs)
    }
    .onDisappear {
      viewModel.cancel()
    }
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 24) {
      Image(systemName: "puzzlepiece.extension.fill")
        .font(.system(size: 38, weight: .semibold))
        .foregroundStyle(VelyraTheme.primary)

      VStack(alignment: .leading, spacing: 8) {
        Text("stremio.import.title")
          .font(.system(size: 42, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
        Text("stremio.import.body")
          .font(.title3)
          .foregroundStyle(.white.opacity(0.62))
      }

      Spacer()

      Button("action.cancel") {
        viewModel.cancel()
        onClose()
      }
      .buttonStyle(VelyraGlassButtonStyle())
    }
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .creatingLink:
      progress("stremio.creatingLink")

    case .awaitingAuthorization(let link):
      authorization(link)

    case .validating:
      progress("stremio.validating")

    case .preview(let preview):
      previewContent(preview)

    case .complete(let count):
      completion(count: count)

    case .failed(let message):
      failure(message: message)
    }
  }

  private func progress(_ key: LocalizedStringKey) -> some View {
    HStack(spacing: 18) {
      ProgressView()
      Text(key)
        .font(.title3)
        .foregroundStyle(.white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }

  private func authorization(_ link: StremioLinkCode) -> some View {
    VStack(alignment: .leading, spacing: 26) {
      Text("stremio.link.instructions")
        .font(.title2.weight(.semibold))
        .foregroundStyle(.white)

      Text(link.linkURL.absoluteString)
        .font(.title3.monospaced())
        .foregroundStyle(.white.opacity(0.72))

      Text(link.code)
        .font(.system(size: 68, weight: .bold, design: .monospaced))
        .tracking(9)
        .foregroundStyle(VelyraTheme.primary)
        .accessibilityLabel(Text("stremio.link.code"))
        .accessibilityValue(link.code)

      HStack(spacing: 14) {
        ProgressView()
        Text("stremio.link.waiting")
          .foregroundStyle(.white.opacity(0.68))
      }

      Label("stremio.link.security", systemImage: "lock.shield.fill")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.56))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }

  private func previewContent(_ preview: StremioImportPreview) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      if preview.candidates.isEmpty {
        Text("stremio.preview.empty")
          .font(.title2)
          .foregroundStyle(.white.opacity(0.72))
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      } else {
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(preview.candidates) { candidate in
              candidateRow(candidate)
            }
          }
        }

        HStack {
          Text("stremio.preview.readOnly")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.5))

          Spacer()

          Button("stremio.import.confirm") {
            let merged = viewModel.confirm(existing: existingURLs)
            onImport(merged)
          }
          .buttonStyle(VelyraGlassButtonStyle(prominent: true))
          .disabled(preview.selectedImportCount == 0)
        }
      }
    }
  }

  private func candidateRow(_ candidate: StremioAddonCandidate) -> some View {
    Button {
      viewModel.toggleSelection(candidateID: candidate.id)
    } label: {
      HStack(spacing: 20) {
        Image(
          systemName: candidate.isSelected
            ? "checkmark.circle.fill"
            : candidateStatusSymbol(candidate.status)
        )
        .font(.title2)
        .foregroundStyle(candidate.isSelected ? VelyraTheme.primary : .white.opacity(0.46))

        VStack(alignment: .leading, spacing: 5) {
          Text(candidate.manifest.name)
            .font(.headline)
            .foregroundStyle(.white)
          Text(candidate.redactedHost)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
        }

        Spacer()

        Text(candidateStatusKey(candidate.status))
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(candidate.status == .new ? .white : .white.opacity(0.5))
      }
      .padding(.horizontal, 22)
      .frame(minHeight: 78)
      .background(
        candidate.isSelected
          ? VelyraTheme.primary.opacity(0.12)
          : Color.white.opacity(0.035),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
    }
    .buttonStyle(.plain)
    .disabled(candidate.status != .new)
  }

  private func completion(count: Int) -> some View {
    VStack(spacing: 24) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 68))
        .foregroundStyle(VelyraTheme.primary)
      Text(String(format: String(localized: "stremio.import.complete"), count))
        .font(.title2.weight(.bold))
        .foregroundStyle(.white)
      Button("action.done") { onClose() }
        .buttonStyle(VelyraGlassButtonStyle(prominent: true))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func failure(message: String) -> some View {
    VStack(spacing: 22) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 58))
        .foregroundStyle(.yellow)
      Text(message)
        .font(.title3)
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
      HStack(spacing: 16) {
        Button("action.retry") {
          viewModel.start(installed: existingURLs)
        }
        .buttonStyle(VelyraGlassButtonStyle(prominent: true))
        Button("action.cancel") { onClose() }
          .buttonStyle(VelyraGlassButtonStyle())
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func candidateStatusSymbol(_ status: StremioAddonCandidateStatus) -> String {
    switch status {
    case .new: "circle"
    case .installed: "checkmark.circle"
    case .incompatible: "exclamationmark.triangle"
    }
  }

  private func candidateStatusKey(_ status: StremioAddonCandidateStatus) -> LocalizedStringKey {
    switch status {
    case .new: "stremio.status.new"
    case .installed: "stremio.status.installed"
    case .incompatible: "stremio.status.incompatible"
    }
  }
}
