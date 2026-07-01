import SwiftUI

struct SnapCraftApp: App {
    @StateObject private var controller = AppController()
    @StateObject private var updater = UpdaterController()

    var body: some Scene {
        MenuBarExtra("SnapCraft", systemImage: "camera.viewfinder") {
            MenuBarContent(controller: controller, updater: updater)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The menu shown from the status-bar item. Capture rows display their current
/// global shortcut; selecting a row runs the same path as the hot key.
private struct MenuBarContent: View {
    @ObservedObject var controller: AppController
    @ObservedObject var updater: UpdaterController
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ForEach(CaptureKind.allCases) { kind in
            Button(menuTitle(kind)) { controller.handle(kind) }
        }
        Divider()
        Button("Settings…") { controller.openSettings() }
        Button("Check for Updates…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
        Divider()
        Button("Quit SnapCraft") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func menuTitle(_ kind: CaptureKind) -> String {
        let caps = settings.shortcuts[kind]?.keyCaps.joined() ?? ""
        return "\(kind.title)   \(caps)"
    }
}
