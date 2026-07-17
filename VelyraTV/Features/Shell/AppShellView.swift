import SwiftUI
import UIKit

struct AppShellView: View {
  @EnvironmentObject private var appState: AppState
  @SceneStorage("velyra.selectedSection") private var restoredSectionRaw = AppSection.home.rawValue
  @State private var selectedSection: AppSection = .home
  @FocusState private var focusedSection: AppSection?

  var body: some View {
    ZStack(alignment: .top) {
      content
        .ignoresSafeArea()

      navigationBar
        .padding(.top, 30)
        .padding(.horizontal, 64)

      if !appState.networkStatus.isConnected {
        offlineBadge
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .padding(.trailing, 54)
          .padding(.bottom, 38)
      }
    }
    .onAppear {
      selectedSection = AppSection(rawValue: restoredSectionRaw) ?? .home
      focusedSection = selectedSection
    }
    .onChange(of: selectedSection) { _, value in
      restoredSectionRaw = value.rawValue
    }
    .onChange(of: appState.networkStatus.isConnected) { _, isConnected in
      guard !isConnected else { return }
      postQueuedAccessibilityAnnouncement(String(localized: "network.offline"))
    }
    .fullScreenCover(item: $appState.deepLinkedItem) { item in
      MediaDetailsView(item: item).environmentObject(appState)
    }
  }

  @ViewBuilder
  private var content: some View {
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

  private var navigationBar: some View {
    HStack(spacing: 6) {
      Text("VELYRA")
        .font(.system(size: 24, weight: .black, design: .rounded))
        .tracking(4)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .accessibilityLabel("Velyra")

      ForEach(AppSection.allCases) { section in
        Button {
          selectedSection = section
        } label: {
          Label(LocalizedStringKey(section.titleKey), systemImage: section.systemImage)
            .labelStyle(.titleAndIcon)
            .font(.headline.weight(section == selectedSection ? .bold : .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(minHeight: 54)
            .background {
              if section == selectedSection {
                Capsule().fill(VelyraTheme.primary.opacity(0.86))
              }
            }
        }
        .buttonStyle(.plain)
        .focused($focusedSection, equals: section)
        .accessibilityAddTraits(section == selectedSection ? .isSelected : [])
      }
    }
    .padding(8)
    .velyraGlass(cornerRadius: 28)
    .accessibilityElement(children: .contain)
  }
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
