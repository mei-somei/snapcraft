import AppKit
import Sparkle

/// Thin wrapper around Sparkle's standard updater. Owns the updater lifecycle
/// and exposes a `checkForUpdates()` entry point for the menu-bar item, plus a
/// `canCheckForUpdates` flag the UI binds to so the row disables itself while a
/// check is already in flight.
///
/// The update feed URL and the EdDSA public key live in Info.plist
/// (`SUFeedURL` and `SUPublicEDKey`), so no configuration is needed here. See
/// docs/RELEASING.md for how those values are produced.
@MainActor
final class UpdaterController: ObservableObject {

    /// Drives the menu row's enabled state (Sparkle disables checks during an
    /// in-progress update session).
    @Published var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController

    init() {
        // `startingUpdater: true` schedules the automatic background check on the
        // interval Sparkle persists in user defaults. Passing nil delegates uses
        // Sparkle's default behaviour, which is what we want.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// Triggers a user-initiated update check (shows progress/UI on no update).
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
