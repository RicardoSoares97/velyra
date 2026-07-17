import SwiftUI
import UIKit

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
      background
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 28) {
          header
          searchField
          filters
          resultContent
          Spacer(minLength: 80)
        }
        .padding(.horizontal, 72)
        .padding(.top, 130)
      }
    }
    .task {
      await viewModel.loadHistory()
      searchFocused = true
    }
    .task(id: SearchTaskID(query: query, kind: viewModel.kindFilter, sort: viewModel.sort)) {
      do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
      guard !Task.isCancelled else { return }
      await performSearch(saveToHistory: false)
    }
    .onChange(of: viewModel.state) { _, state in
      postQueuedAccessibilityAnnouncement(accessibilityAnnouncement(for: state))
    }
    .fullScreenCover(item: $selectedItem) { item in
      MediaDetailsView(item: item).environmentObject(appState)
    }
  }

  private var background: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      LinearGradient(
        colors: [Color.indigo.opacity(0.2), .black, VelyraTheme.primary.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
      .accessibilityHidden(true)
    }
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
        .onSubmit { Task { await performSearch(saveToHistory: true) } }
        .accessibilityLabel(Text("search.accessibilityLabel"))
      if !query.isEmpty {
        Button {
          query = ""
        } label: {
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

  private var filters: some View {
    HStack(spacing: 14) {
      ForEach(SearchViewModel.KindFilter.allCases) { filter in
        Button {
          viewModel.kindFilter = filter
          viewModel.filtersChanged()
        } label: {
          Text(LocalizedStringKey(filter.titleKey))
            .font(.headline)
            .padding(.horizontal, 20)
            .frame(minHeight: 54)
            .background {
              if viewModel.kindFilter == filter {
                Capsule().fill(VelyraTheme.primary.opacity(0.86))
              }
            }
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .accessibilityAddTraits(viewModel.kindFilter == filter ? .isSelected : [])
      }

      Spacer()

      Picker("search.year", selection: $viewModel.yearFilter) {
        ForEach(SearchViewModel.YearFilter.allCases) { value in
          Text(LocalizedStringKey(value.titleKey)).tag(value)
        }
      }
      .frame(width: 270)
      .onChange(of: viewModel.yearFilter) { _, _ in viewModel.filtersChanged() }

      Picker("search.rating", selection: $viewModel.ratingFilter) {
        ForEach(SearchViewModel.RatingFilter.allCases) { value in
          Text(LocalizedStringKey(value.titleKey)).tag(value)
        }
      }
      .frame(width: 230)
      .onChange(of: viewModel.ratingFilter) { _, _ in viewModel.filtersChanged() }

      Picker("search.sort", selection: $viewModel.sort) {
        ForEach(SearchViewModel.Sort.allCases) { value in
          Text(LocalizedStringKey(value.titleKey)).tag(value)
        }
      }
      .frame(width: 330)
      .onChange(of: viewModel.sort) { _, _ in viewModel.filtersChanged() }
    }
  }

  @ViewBuilder
  private var resultContent: some View {
    switch viewModel.state {
    case .idle:
      recentSearches
    case .searching:
      HStack(spacing: 14) {
        ProgressView().tint(VelyraTheme.primary)
        Text("search.searching")
      }
      .foregroundStyle(.white)
      .accessibilityElement(children: .combine)
    case .empty:
      emptyView(
        title: "search.empty.title", body: String(localized: "search.empty.body"),
        icon: "film.stack")
    case .failed(let message):
      emptyView(title: "search.error.title", body: message, icon: "wifi.exclamationmark")
    case .results:
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 28)], spacing: 34) {
        ForEach(viewModel.results) { item in
          HomeMediaCard(item: item, style: .poster) { selectedItem = item }
            .task { await viewModel.loadNextPageIfNeeded(currentItem: item) }
        }
      }
      .padding(.vertical, 18)
    }
  }

  @ViewBuilder
  private var recentSearches: some View {
    if viewModel.recentSearches.isEmpty || !appState.preferences.searchHistoryEnabled {
      Label("search.suggestion", systemImage: "sparkles")
        .font(.headline)
        .foregroundStyle(.white.opacity(0.62))
        .padding(.top, 18)
    } else {
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          Text("search.recent").font(.title2.bold()).foregroundStyle(.white)
          Spacer()
          Button("search.clearHistory") { Task { await viewModel.clearHistory() } }
            .buttonStyle(VelyraGlassButtonStyle())
        }
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 14) {
            ForEach(viewModel.recentSearches, id: \.self) { value in
              Button(value) {
                query = value
                Task { await performSearch(saveToHistory: true) }
              }
              .buttonStyle(VelyraGlassButtonStyle())
            }
          }
          .padding(.vertical, 8)
        }
      }
    }
  }

  private func emptyView(title: LocalizedStringKey, body: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: icon).font(.system(size: 38)).foregroundStyle(VelyraTheme.primary)
      Text(title).font(.title2.bold())
      Text(body).font(.body).foregroundStyle(.secondary)
    }
    .foregroundStyle(.white)
    .padding(28)
    .velyraGlass(cornerRadius: 26)
    .frame(maxWidth: 720, alignment: .leading)
  }

  private func performSearch(saveToHistory: Bool) async {
    await viewModel.search(
      query: query,
      language: languageCode,
      addonManifestURLs: appState.preferences.activeAddonManifestURLs,
      saveToHistory: saveToHistory && appState.preferences.searchHistoryEnabled
    )
  }

  private func accessibilityAnnouncement(for state: SearchViewModel.State) -> String? {
    switch state {
    case .empty:
      String(localized: "search.empty.body")
    case .failed(let message):
      message
    case .idle, .searching, .results:
      nil
    }
  }
}

private struct SearchTaskID: Hashable {
  let query: String
  let kind: SearchViewModel.KindFilter
  let sort: SearchViewModel.Sort
}

@MainActor
private func postQueuedAccessibilityAnnouncement(_ message: String?) {
  guard let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    return
  }
  let announcement = NSMutableAttributedString(string: message)
  announcement.addAttribute(
    .accessibilitySpeechQueueAnnouncement,
    value: true,
    range: NSRange(location: 0, length: announcement.length)
  )
  UIAccessibility.post(notification: .announcement, argument: announcement)
}
