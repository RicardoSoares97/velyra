import SwiftUI

struct SearchView: View {
  @EnvironmentObject private var appState: AppState
  @StateObject private var viewModel = SearchViewModel()
  @State private var query = ""
  @State private var selectedItem: MediaItem?
  @FocusState private var searchFocused: Bool

  private var languageCode: String {
    appState.preferences.language.locale?.identifier ?? Locale.current.identifier
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      LinearGradient(
        colors: [Color.indigo.opacity(0.2), .black, VelyraTheme.primary.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 28) {
        header
        searchField
        resultContent
        Spacer(minLength: 60)
      }
      .padding(.horizontal, 72)
      .padding(.top, 130)
    }
    .task(id: query) {
      do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
      guard !Task.isCancelled else { return }
      await viewModel.search(
        query: query,
        language: languageCode,
        addonManifestURLs: appState.preferences.addonManifestURLs
      )
    }
    .fullScreenCover(item: $selectedItem) { item in
      MediaDetailsView(item: item)
    }
    .onAppear { searchFocused = true }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("search.title")
        .font(.system(size: 52, weight: .black, design: .rounded))
        .foregroundStyle(.white)
      Text("search.body")
        .font(.title3)
        .foregroundStyle(.white.opacity(0.64))
    }
  }

  private var searchField: some View {
    HStack(spacing: 16) {
      Image(systemName: "magnifyingglass")
        .font(.title2)
        .foregroundStyle(VelyraTheme.primary)
      TextField("search.placeholder", text: $query)
        .textFieldStyle(.plain)
        .font(.title2)
        .focused($searchFocused)
        .submitLabel(.search)
        .accessibilityLabel(Text("search.accessibilityLabel"))
      if !query.isEmpty {
        Button { query = "" } label: {
          Image(systemName: "xmark.circle.fill")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("search.clear"))
      }
    }
    .padding(.horizontal, 24)
    .frame(height: 76)
    .velyraGlass(cornerRadius: 26, interactive: true)
    .frame(maxWidth: 1_050)
  }

  @ViewBuilder
  private var resultContent: some View {
    switch viewModel.state {
    case .idle:
      suggestionView
    case .searching:
      HStack(spacing: 14) {
        ProgressView().tint(VelyraTheme.primary)
        Text("search.searching")
      }
      .foregroundStyle(.white)
    case .empty:
      emptyView(
        title: "search.empty.title",
        body: String(localized: "search.empty.body"),
        icon: "film.stack"
      )
    case .failed(let message):
      emptyView(title: "search.error.title", body: message, icon: "wifi.exclamationmark")
    case .results:
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 26) {
          ForEach(viewModel.results) { item in
            HomeMediaCard(item: item, style: .poster) {
              selectedItem = item
            }
          }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 4)
      }
    }
  }

  private var suggestionView: some View {
    Label("search.suggestion", systemImage: "sparkles")
      .font(.headline)
      .foregroundStyle(.white.opacity(0.62))
      .padding(.top, 18)
  }

  private func emptyView(title: LocalizedStringKey, body: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 38))
        .foregroundStyle(VelyraTheme.primary)
      Text(title).font(.title2.bold())
      Text(body).font(.body).foregroundStyle(.secondary)
    }
    .foregroundStyle(.white)
    .padding(28)
    .velyraGlass(cornerRadius: 26)
    .frame(maxWidth: 720, alignment: .leading)
  }
}
