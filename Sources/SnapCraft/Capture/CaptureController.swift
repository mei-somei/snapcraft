import AppKit
import ScreenCaptureKit

/// Orchestrates the three capture flows (area / window / fullscreen), bridging
/// the selection overlay and ScreenCaptureKit, and hands the resulting image to
/// `onCapture`. Our own windows are excluded so the editor never appears in a shot.
@MainActor
final class CaptureController {

    var onCapture: ((CapturedImage) -> Void)?
    private let settings: AppSettings
    private var overlay: RegionSelectionOverlay?

    init(settings: AppSettings) { self.settings = settings }

    func capture(_ kind: CaptureKind) {
        switch kind {
        case .selectedArea: captureArea()
        case .window:       captureWindow()
        case .fullscreen:   captureFullscreen()
        case .pin:          break // handled by AppController (pins last capture)
        }
    }

    // MARK: Area

    private func captureArea() {
        // Record the app that was frontmost *before* our overlay steals focus,
        // so the screenshot can be named after the app the user was looking at.
        let target = NSWorkspace.shared.frontmostApplication
        Task {
            guard let content = try? await ScreenCaptureService.shareableContent() else { return }
            let ours = ownWindows(in: content)
            let overlay = RegionSelectionOverlay()
            self.overlay = overlay
            overlay.begin(mode: .region) { [weak self] result in
                guard let self, let result else { self?.overlay = nil; return }
                Task { await self.grabRegion(result, excluding: ours, content: content, target: target) }
            }
        }
    }

    private func grabRegion(_ result: RegionSelectionOverlay.Result,
                            excluding ours: [SCWindow],
                            content: SCShareableContent,
                            target: NSRunningApplication?) async {
        let global = CGPoint(x: result.screen.frame.midX, y: result.screen.frame.midY)
        guard let display = ScreenCaptureService.display(containing: global, in: content),
              let full = try? await ScreenCaptureService.captureDisplay(display, excluding: ours)
        else { overlay = nil; return }
        let scale = result.screen.backingScaleFactor
        if let cropped = ScreenCaptureService.crop(full, to: result.rect, scale: scale) {
            // Global (bottom-left origin) frame of the selection so the editor
            // can open as an in-place layer right over the captured region.
            let screen = result.screen.frame
            let frame = CGRect(x: screen.minX + result.rect.minX,
                               y: screen.maxY - result.rect.maxY,
                               width: result.rect.width,
                               height: result.rect.height)
            deliver(cropped, screenFrame: frame,
                    app: target?.localizedName,
                    detail: frontWindowTitle(of: target, in: content))
        }
        overlay = nil
    }

    // MARK: Window

    private func captureWindow() {
        Task {
            guard let content = try? await ScreenCaptureService.shareableContent() else { return }
            let pickable = content.windows.filter { win in
                win.isOnScreen && win.frame.width > 40 && win.frame.height > 40 &&
                win.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            }
            let overlay = RegionSelectionOverlay()
            self.overlay = overlay
            overlay.begin(mode: .window, windows: pickable) { [weak self] result in
                guard let self, let result, let win = result.window else { self?.overlay = nil; return }
                Task {
                    if let img = try? await ScreenCaptureService.captureWindow(win) {
                        self.deliver(img,
                                     app: win.owningApplication?.applicationName,
                                     detail: win.title)
                    }
                    self.overlay = nil
                }
            }
        }
    }

    // MARK: Fullscreen

    private func captureFullscreen() {
        let target = NSWorkspace.shared.frontmostApplication
        Task {
            guard let content = try? await ScreenCaptureService.shareableContent() else { return }
            let mouse = NSEvent.mouseLocation
            guard let display = ScreenCaptureService.display(containing: mouse, in: content),
                  let img = try? await ScreenCaptureService.captureDisplay(display, excluding: ownWindows(in: content))
            else { return }
            deliver(img, app: target?.localizedName,
                    detail: frontWindowTitle(of: target, in: content))
        }
    }

    // MARK: Helpers

    private func ownWindows(in content: SCShareableContent) -> [SCWindow] {
        content.windows.filter {
            $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
    }

    /// Title of the frontmost on-screen window owned by `app`. `content.windows`
    /// is front-to-back, so the first match is the app's topmost window.
    private func frontWindowTitle(of app: NSRunningApplication?,
                                  in content: SCShareableContent) -> String? {
        guard let bundleID = app?.bundleIdentifier else { return nil }
        return content.windows.first {
            $0.owningApplication?.bundleIdentifier == bundleID &&
            $0.isOnScreen && !($0.title ?? "").isEmpty
        }?.title
    }

    private func deliver(_ image: NSImage, screenFrame: CGRect? = nil,
                         app: String? = nil, detail: String? = nil) {
        if settings.captureSound { NSSound(named: "Pop")?.play() }
        var capture = CapturedImage(image: image,
                                    caption: CapturedImage.makeCaption(app: app, detail: detail))
        capture.screenFrame = screenFrame
        onCapture?(capture)
    }
}
