import ScreenCaptureKit
import AppKit

/// Thin wrapper over ScreenCaptureKit that grabs still images of displays and
/// windows. Region capture is done by grabbing the whole display and cropping,
/// which keeps the selection overlay independent of the capture backend.
enum ScreenCaptureService {

    enum CaptureError: Error { case noShareableContent, captureFailed }

    /// Current shareable content (displays + on-screen windows), excluding
    /// SnapCraft's own windows so our overlay never appears in the shot.
    static func shareableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
    }

    /// Full-resolution image of an entire display.
    static func captureDisplay(_ display: SCDisplay,
                               excluding windows: [SCWindow] = []) async throws -> NSImage {
        let filter = SCContentFilter(display: display, excludingWindows: windows)
        let config = SCStreamConfiguration()
        config.width = display.width * scaleFactor(for: display)
        config.height = display.height * scaleFactor(for: display)
        config.showsCursor = false
        config.scalesToFit = false
        let cg = try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: config)
        return NSImage(cgImage: cg, size: NSSize(width: display.width, height: display.height))
    }

    /// Crop an already-captured display image to a rect expressed in the
    /// display's point space (top-left origin), honoring the backing scale.
    static func crop(_ image: NSImage, to rect: CGRect, scale: CGFloat) -> NSImage? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cg = rep.cgImage else { return nil }
        let pxRect = CGRect(x: rect.minX * scale, y: rect.minY * scale,
                            width: rect.width * scale, height: rect.height * scale)
        guard let cropped = cg.cropping(to: pxRect) else { return nil }
        return NSImage(cgImage: cropped, size: rect.size)
    }

    /// Capture a single window at full fidelity (used by window-mode capture).
    static func captureWindow(_ window: SCWindow) async throws -> NSImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scale = NSScreen.screens.first?.backingScaleFactor ?? 2
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        let cg = try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: config)
        return NSImage(cgImage: cg, size: window.frame.size)
    }

    /// Backing scale factor for the NSScreen matching a SCDisplay.
    static func scaleFactor(for display: SCDisplay) -> Int {
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[.init("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
        }
        return Int(screen?.backingScaleFactor ?? 2)
    }

    /// The SCDisplay whose frame contains a global (AppKit, bottom-left origin) point.
    static func display(containing globalPoint: CGPoint,
                        in content: SCShareableContent) -> SCDisplay? {
        content.displays.first { display in
            guard let screen = NSScreen.screens.first(where: {
                ($0.deviceDescription[.init("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
            }) else { return false }
            return screen.frame.contains(globalPoint)
        } ?? content.displays.first
    }
}
