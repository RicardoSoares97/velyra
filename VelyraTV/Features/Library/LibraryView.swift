import SwiftUI

struct LibraryView: View {
  @EnvironmentObject private var appState: AppState
  @StateObject private var viewModel = TraktLibraryViewModel()
  @State private var selectedItem: MediaItem?
  @State private var showsListEditor = false
  @State private var newListName = ""
  @State private var newListDescription = ""
  @State private var editingListID: Int?
  @State private var editingListName = ""
  @State private var editingListDescription = ""

  private var languageCode: String {
    appState.preferences.language.locale?.identifier ?? Locale.current.identifier
  }

  private var loadID: String {
    "\(languageCode):\(appState.traktSession.isConnected)"
  }

  var body: some View {
    ZStack {
      CinematicBackgroundView(videoName: "library-ambient", focalColor: .purple)
      content
    }
    .fullScreenCover(item: $selectedItem) { item in
      MediaDetailsView(item: item)
    }
    .sheet(isPresented: $showsListEditor) {
      ListEditorSheet(
        name: $newListName,
        description: $newListDescription,
        onCancel: { showsListEditor = false },
        onSave: {
          let name = newListName
          let description = newListDescription.isEmpty ? nil : newListDescription
          showsListEditor = false
          newListName = ""
          newListDescription = ""
          Task { await viewModel.createList(name: name, description: description) }
        }
      )
    }
    .sheet(
      isPresented: Binding(
        get: { editingListID != nil },
        set: { if !$0 { editingListID = nil } }
      )
    ) {
      ListEditorSheet(
        name: $editingListName,
        description: $editingListDescription,
        onCancel: { editingListID = nil },
        onSave: {
          guard let id = editingListID else { return }
          let name = editingListName
          let description = editingListDescription.isEmpty ? nil : editingListDescription
          editingListID = nil
          Task { await viewModel.updateList(id: id, name: name, description: description) }
        }
      )
    }
    .task(id: loadID) {
      await viewModel.load(
        repository: appState.traktLibraryRepository,
        language: languageCode
      )
    }
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView("library.loading")
        .controlSize(.large)
        .tint(VelyraTheme.primary)
    case .failed(let message):
      disconnectedView(message: message)
    case .loaded(let content, let isStale, let warning):
      library(content, isStale: isStale, warning: warning)
    }
  }

  private func library(
    _ content: TraktLibraryContent,
    isStale: Bool,
    warning: String?
  ) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 34) {
        header(content)

        if !appState.traktSession.isConnected || isStale || warning != nil {
          syncBanner(isStale: isStale, warning: warning)
        }

        categoryPicker(content.categories)
        libraryControls

        let items = viewModel.visibleItems(in: content)
        if items.isEmpty {
          emptyCategory
        } else {
          LazyVGrid(
            columns: [
              GridItem(.adaptive(minimum: 220, maximum: 270), spacing: 30, alignment: .top)
            ],
            alignment: .leading,
            spacing: 36
          ) {
            ForEach(items) { item in
              LibraryMediaCard(item: item) {
                selectedItem = item.media
              }
              .contextMenu {
                contextMenu(for: item, content: content)
              }
            }
          }
        }
      }
      .padding(.top, 170)
      .padding(.horizontal, 72)
      .padding(.bottom, 110)
    }
    .refreshable { await viewModel.refresh() }
  }

  private func header(_ content: TraktLibraryContent) -> some View {
    HStack(alignment: .bottom, spacing: 30) {
      VStack(alignment: .leading, spacing: 8) {
        Text("library.title")
          .font(.system(size: 58, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
        Text(
          content.profile.map {
            String(format: String(localized: "library.welcome"), $0.displayName)
          }
            ?? String(localized: "library.body")
        )
        .font(.title3)
        .foregroundStyle(.white.opacity(0.66))
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 7) {
        if let syncedAt = content.syncedAt {
          Text(
            String(
              format: String(localized: "library.lastSync"),
              syncedAt.formatted(date: .omitted, time: .shortened))
          )
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.54))
        }
        if content.pendingMutationCount > 0 {
          Button {
            Task { await viewModel.retryPendingChanges() }
          } label: {
            Label(
              String(
                format: String(localized: "library.pendingChanges"), content.pendingMutationCount),
              systemImage: content.failedMutationCount > 0
                ? "exclamationmark.icloud.fill" : "icloud.and.arrow.up"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(VelyraTheme.primary)
          }
          .buttonStyle(.plain)
          .accessibilityHint("library.pendingChanges.retryHint")
        }
      }
    }
  }

  private func syncBanner(isStale: Bool, warning: String?) -> some View {
    HStack(spacing: 18) {
      Image(
        systemName: appState.traktSession.isConnected
          ? "icloud.slash" : "person.crop.circle.badge.exclamationmark"
      )
      .font(.title2)
      .foregroundStyle(VelyraTheme.primary)

      VStack(alignment: .leading, spacing: 5) {
        Text(appState.traktSession.isConnected ? "library.cached.title" : "library.offline.title")
          .font(.headline)
        Text(warning ?? String(localized: isStale ? "library.cached.body" : "library.offline.body"))
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.64))
      }

      Spacer()

      if appState.traktSession.isConnected {
        Button("action.retry") { Task { await viewModel.refresh() } }
          .buttonStyle(VelyraGlassButtonStyle())
      } else {
        Button("trakt.connect") { appState.traktSession.connect() }
          .buttonStyle(VelyraGlassButtonStyle(prominent: true))
      }
    }
    .foregroundStyle(.white)
    .padding(24)
    .velyraGlass(cornerRadius: 24)
  }

  private func categoryPicker(_ categories: [TraktLibraryCategory]) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(spacing: 14) {
        ForEach(categories) { category in
          Button {
            viewModel.selectedCategory = category
          } label: {
            Label(category.title, systemImage: category.systemImage)
              .font(.headline)
              .padding(.horizontal, 22)
              .frame(minHeight: 58)
              .background {
                if category == viewModel.selectedCategory {
                  Capsule().fill(VelyraTheme.primary.opacity(0.9))
                }
              }
          }
          .buttonStyle(VelyraGlassButtonStyle())
          .contextMenu {
            if case .personalList(let id, let name) = category, id > 0 {
              Button {
                editingListID = id
                editingListName = name
                editingListDescription = ""
              } label: {
                Label("library.editList", systemImage: "pencil")
              }
              Button(role: .destructive) {
                Task { await viewModel.deleteList(id: id) }
              } label: {
                Label("library.deleteList", systemImage: "trash")
              }
            }
          }
          .accessibilityAddTraits(category == viewModel.selectedCategory ? .isSelected : [])
        }
      }
      .padding(.vertical, 14)
      .padding(.horizontal, 4)
    }
  }

  private var libraryControls: some View {
    HStack(spacing: 18) {
      TextField("library.search.placeholder", text: $viewModel.query)
        .textFieldStyle(.plain)
        .padding(.horizontal, 20)
        .frame(maxWidth: 500, minHeight: 58)
        .velyraGlass(cornerRadius: 18, interactive: true)

      Picker("library.filter.title", selection: $viewModel.mediaFilter) {
        ForEach(TraktLibraryMediaFilter.allCases) { value in
          Text(LocalizedStringKey(value.titleKey)).tag(value)
        }
      }
      .pickerStyle(.menu)

      Picker("library.sort.titleLabel", selection: $viewModel.sort) {
        ForEach(TraktLibrarySort.allCases) { value in
          Text(LocalizedStringKey(value.titleKey)).tag(value)
        }
      }
      .pickerStyle(.menu)

      Spacer()

      Button {
        newListName = ""
        newListDescription = ""
        showsListEditor = true
      } label: {
        Label("library.newList", systemImage: "plus")
      }
      .buttonStyle(VelyraGlassButtonStyle())
    }
  }

  private var emptyCategory: some View {
    ContentUnavailableView {
      Label("library.empty.title", systemImage: viewModel.selectedCategory.systemImage)
    } description: {
      Text("library.empty.body")
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, minHeight: 360)
    .velyraGlass(cornerRadius: 30)
  }

  private func disconnectedView(message: String) -> some View {
    VStack(spacing: 28) {
      VelyraPlaceholderScreen(
        titleKey: "library.connect.title",
        bodyKey: "library.connect.body",
        systemImage: "arrow.triangle.2.circlepath",
        accent: VelyraTheme.primary
      ) {
        Button("trakt.connect") { appState.traktSession.connect() }
          .buttonStyle(VelyraGlassButtonStyle(prominent: true))
      }
      Text(message)
        .font(.caption)
        .foregroundStyle(.white.opacity(0.5))
    }
  }

  @ViewBuilder
  private func contextMenu(
    for item: TraktLibraryDisplayItem,
    content: TraktLibraryContent
  ) -> some View {
    Button {
      selectedItem = item.media
    } label: {
      Label("action.details", systemImage: "info.circle")
    }

    switch viewModel.selectedCategory {
    case .continueWatching:
      Button(role: .destructive) {
        Task { await viewModel.removePlayback(item) }
      } label: {
        Label("library.removeProgress", systemImage: "xmark.circle")
      }
    case .watchlist:
      Button(role: .destructive) {
        Task { await viewModel.setWatchlist(item, isListed: false) }
      } label: {
        Label("library.removeWatchlist", systemImage: "bookmark.slash")
      }
    case .history:
      Button(role: .destructive) {
        Task { await viewModel.removeHistory(item) }
      } label: {
        Label("library.removeHistory", systemImage: "trash")
      }
    case .collection:
      Button(role: .destructive) {
        Task { await viewModel.setCollection(item, isCollected: false) }
      } label: {
        Label("library.removeCollection", systemImage: "rectangle.stack.badge.minus")
      }
    case .ratings:
      Button(role: .destructive) {
        Task { await viewModel.setRating(item, rating: nil) }
      } label: {
        Label("library.removeRating", systemImage: "star.slash")
      }
    case .personalList(let id, _):
      Button(role: .destructive) {
        Task { await viewModel.setListMembership(listID: id, item: item, isListed: false) }
      } label: {
        Label("library.removeFromList", systemImage: "minus.circle")
      }
    }

    if viewModel.selectedCategory != .watchlist {
      Button {
        Task { await viewModel.setWatchlist(item, isListed: true) }
      } label: {
        Label("library.addWatchlist", systemImage: "bookmark")
      }
    }

    if viewModel.selectedCategory != .collection {
      Button {
        Task { await viewModel.setCollection(item, isCollected: true) }
      } label: {
        Label("library.addCollection", systemImage: "rectangle.stack.badge.plus")
      }
    }

    Button {
      Task { await viewModel.markWatched(item) }
    } label: {
      Label("library.markWatched", systemImage: "checkmark.circle")
    }

    let personalLists = content.categories.compactMap { category -> (Int, String)? in
      if case .personalList(let id, let name) = category, id > 0 { return (id, name) }
      return nil
    }
    if !personalLists.isEmpty {
      Menu {
        ForEach(personalLists, id: \.0) { id, name in
          Button(name) {
            Task { await viewModel.setListMembership(listID: id, item: item, isListed: true) }
          }
        }
      } label: {
        Label("library.addToList", systemImage: "text.badge.plus")
      }
    }

    Menu {
      ForEach(1...10, id: \.self) { rating in
        Button("\(rating)/10") {
          Task { await viewModel.setRating(item, rating: rating) }
        }
      }
    } label: {
      Label("library.rate", systemImage: "star")
    }
  }
}

private struct ListEditorSheet: View {
  @Binding var name: String
  @Binding var description: String
  let onCancel: () -> Void
  let onSave: () -> Void

  @FocusState private var focusedField: Field?

  private enum Field { case name, description }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 28) {
        Text("library.newList")
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .foregroundStyle(.white)

        TextField("library.listName", text: $name)
          .textFieldStyle(.plain)
          .padding(20)
          .velyraGlass(cornerRadius: 20, interactive: true)
          .focused($focusedField, equals: .name)

        TextField("library.listDescription", text: $description, axis: .vertical)
          .textFieldStyle(.plain)
          .lineLimit(3...5)
          .padding(20)
          .velyraGlass(cornerRadius: 20, interactive: true)
          .focused($focusedField, equals: .description)

        HStack(spacing: 16) {
          Button("action.cancel", action: onCancel)
            .buttonStyle(VelyraGlassButtonStyle())
          Button("action.save", action: onSave)
            .buttonStyle(VelyraGlassButtonStyle(prominent: true))
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .frame(maxWidth: 760)
      .padding(46)
      .velyraGlass(cornerRadius: 34)
    }
    .onAppear { focusedField = .name }
    .onExitCommand(perform: onCancel)
  }
}

private struct LibraryMediaCard: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var isFocused: Bool

  let item: TraktLibraryDisplayItem
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 11) {
        ZStack(alignment: .bottomLeading) {
          RemoteMediaArtwork(url: item.media.posterURL, title: item.media.title, aspect: .poster)
            .frame(width: 250)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

          if let progress = item.media.progress {
            GeometryReader { proxy in
              Capsule()
                .fill(VelyraTheme.primary)
                .frame(width: proxy.size.width * min(max(progress, 0), 1), height: 7)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: 222, height: 7)
            .padding(14)
          }

          if let rating = item.rating {
            Label("\(rating)", systemImage: "star.fill")
              .font(.caption.bold())
              .padding(.horizontal, 10)
              .padding(.vertical, 7)
              .background(.black.opacity(0.78), in: Capsule())
              .padding(12)
          }
        }
        .overlay {
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
              isFocused ? VelyraTheme.focusRing : .white.opacity(0.1), lineWidth: isFocused ? 4 : 1)
        }

        Text(item.media.title)
          .font(.headline)
          .foregroundStyle(.white)
          .lineLimit(1)

        Text(item.media.subtitle ?? item.media.releaseYear.map(String.init) ?? "")
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.6))
          .lineLimit(1)
      }
      .frame(width: 250, alignment: .leading)
      .scaleEffect(isFocused && !reduceMotion ? 1.05 : 1)
      .shadow(color: .black.opacity(isFocused ? 0.5 : 0.15), radius: isFocused ? 28 : 10, y: 14)
    }
    .buttonStyle(.plain)
    .focused($isFocused)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(item.media.title)
    .accessibilityValue(item.media.accessibilitySummary)
    .accessibilityHint(Text("media.openDetails.hint"))
    .accessibleMotion(value: isFocused)
  }
}
