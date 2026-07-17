import SwiftUI

@main
struct VelyraTVApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var appState = AppState()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(appState)
        .task { await appState.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
          Task { await appState.handleScenePhase(phase) }
        }
        .onOpenURL { appState.handleOpenURL($0) }
    }
  }
}
