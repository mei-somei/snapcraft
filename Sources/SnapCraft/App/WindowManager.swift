import AppKit
import SwiftUI

/// Actions the editor surfaces back to the app coordinator (export + nav).
struct EditorActions {
    var copy: () -> Void
    var save: () -> Void
    var saveAs: () -> Void
    var pin: () -> Void
    var openSettings: () -> Void
    var runOCR: (CGRect) -> Void
}

/// Creates and retains the app's AppKit windows: editor windows (one per
/// capture), a single settings window, and floating pin windows. SwiftUI scenes
/// are awkward for data-carrying, on-demand windows, so we host views directly.
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {

    private var windows: Set<NSWindow> = []
    private weak var settingsWindow: NSWindow?

    // MARK: Editor

    @discardableResult
    func openEditor(viewModel: EditorViewModel,
                    settings: AppSettings,
                    actions: EditorActions,
                    inPlaceFrame: CGRect? = nil) -> NSWindow {
        let root = EditorView(viewModel: viewModel, actions: actions)
            .environmentObject(settings)
        let host = NSHostingController(rootView: root)

        let window: NSWindow
        if let frame = inPlaceFrame {
            // Floating in-place layer parked top-right; tools on top.
            window = makeInPlaceWindow(content: host, frame: frame)
        } else {
            window = makeWindow(content: host, size: NSSize(width: 1180, height: 760),
                                title: "SnapCraft")
            window.minSize = NSSize(width: 760, height: 520)
        }
        present(window)
        return window
    }

    /// Close an editor window (used after copy/save dismisses the in-place layer).
    func dismiss(_ window: NSWindow) { close(window) }

    // MARK: Settings

    func openSettings(settings: AppSettings) {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = SettingsView().environmentObject(settings)
        let host = NSHostingController(rootView: root)
        let window = makeWindow(content: host, size: NSSize(width: 880, height: 640),
                                title: "SnapCraft Settings")
        window.minSize = NSSize(width: 720, height: 520)
        settingsWindow = window
        present(window)
    }

    // MARK: Pin

    func openPin(image: NSImage) {
        let size = pinSize(for: image.size)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let view = PinView(image: image) { [weak self, weak window] in
            if let window { self?.close(window) }
        }
        window.contentViewController = NSHostingController(rootView: view)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()
        window.delegate = self
        windows.insert(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func pinSize(for imageSize: CGSize) -> NSSize {
        let maxDim: CGFloat = 520
        let scale = min(1, maxDim / max(imageSize.width, imageSize.height))
        return NSSize(width: max(120, imageSize.width * scale),
                      height: max(90, imageSize.height * scale))
    }

    // MARK: Window plumbing

    private func makeWindow(content: NSViewController, size: NSSize, title: String) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.contentViewController = content
        window.title = title
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        return window
    }

    /// A floating editor window for a region capture. Sized to hold the
    /// screenshot at its native 1:1 size plus a whiteboard margin (room for the
    /// dot-grid backdrop and the floating tool clusters), then parked in the
    /// top-right corner of the capture's screen. Stays on top until the user
    /// copies or saves (see `AppController`).
    private func makeInPlaceWindow(content: NSViewController, frame region: CGRect) -> NSWindow {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(region) }) ?? NSScreen.main
        let vis = screen?.visibleFrame ?? region

        // Extra room on the left for the vertical tool strip.
        let inset: CGFloat = 16
        var frame = CGRect(x: 0, y: 0,
                           width: min(region.width + 270, vis.width),
                           height: min(region.height + 240, vis.height))
        frame.origin.x = vis.maxX - frame.width - inset     // right edge
        frame.origin.y = vis.maxY - frame.height - inset    // top edge (bottom-left origin)

        let window = NSWindow(contentRect: frame,
                              styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.contentViewController = content
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrame(frame, display: false)
        return window
    }

    private func present(_ window: NSWindow) {
        windows.insert(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func close(_ window: NSWindow) {
        window.orderOut(nil)
        windows.remove(window)
    }

    func windowWillClose(_ notification: Notification) {
        guard let win = notification.object as? NSWindow else { return }
        windows.remove(win)
    }
}
