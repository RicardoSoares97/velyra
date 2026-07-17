import SwiftUI
import UIKit

struct AppShellView: View {
  @EnvironmentObject private var appState: AppState
  @SceneStorage("velyra.selectedSection") private var restoredSectionRaw =
    AppSection.home.rawValue
  @State private var selectedSection: AppSection = .home

  var body: some View {
    ZStack {
      shell

      if !appState.networkStatus.isConnected {
        offlineBadge
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .padding(.trailing, 54)
          .padding(.bottom, 38)
      }
    }
    .onAppear {
      selectedSection = AppSection(rawValue: restoredSectionRaw) ?? .home
    }
    .onChange(of: selectedSection) { _, value in
      restoredSectionRaw = value.rawValue
    }
    .onChange(of: appState.networkStatus.isConnected) { _, isConnected in
      guard !isConnected else { return }
      postShellAccessibilityAnnouncement(String(localized: "network.offline"))
    }
    .fullScreenCover(item: $appState.deepLinkedItem) { item in
      MediaDetailsView(item: item).environmentObject(appState)
    }
  }

  @ViewBuilder
  private var shell: some View {
    if #available(tvOS 18.0, *) {
      adaptiveTabs
        .tabViewStyle(.sidebarAdaptable)
    } else {
      LegacyEditorialRail(selection: $selectedSection) {
        selectedContent
      }
    }
  }

  private var adaptiveTabs: some View {
    TabView(selection: $selectedSection) {
      tab(HomeView(), section: .home)
      tab(SearchView(), section: .search)
      tab(LibraryView(), section: .library)
      tab(AddonsView(), section: .addons)
      tab(SettingsView(), section: .settings)
    }
  }

  private func tab<Content: View>(_ content: Content, section: AppSection) -> some View {
    content
      .tag(section)
      .tabItem {
        Label(LocalizedStringKey(section.titleKey), systemImage: section.systemImage)
      }
  }

  @ViewBuilder
  private var selectedContent: some View {
    switch selectedSection {
    case .home: HomeView()
    case .search: SearchView()
    case .library: LibraryView()
    case .addons: AddonsView()
    case .settings: SettingsView()
    }
  }

  private var offlineBadge: some View {
    Label("network.offline", systemImage: "wifi.slash")
      .font(.headline)
      .foregroundStyle(.white)
      .padding(.horizontal, 18)
      .frame(minHeight: 52)
      .background(.black.opacity(0.72), in: Capsule())
      .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 1) }
  }
}

@MainActor
private func postShellAccessibilityAnnouncement(_ message: String?) {
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
