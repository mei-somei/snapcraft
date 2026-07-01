import AppKit
import ScreenCaptureKit

/// A full-screen dimmed overlay for drag-selecting a capture region, plus a
/// "window mode" that highlights and picks the window under the pointer.
/// Reports the chosen region in the target screen's top-left point space.
final class RegionSelectionOverlay {

    enum Mode { case region, window }

    struct Result {
        let screen: NSScreen
        let rect: CGRect          // top-left origin, screen-local points
        let window: SCWindow?     // set in window mode
    }

    private var window: NSWindow?
    private var monitor: Any?
    private var globalMonitor: Any?
    private var completion: ((Result?) -> Void)?

    /// Present the overlay on the screen under the cursor.
    func begin(mode: Mode,
               windows: [SCWindow] = [],
               completion: @escaping (Result?) -> Void) {
        self.completion = completion

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main!

        // A plain borderless NSWindow refuses to become key, which kills keyboard
        // focus (Escape) and makes mouse routing unreliable. Use a subclass that
        // opts back in so the overlay actually receives events.
        let win = KeyableOverlayWindow(contentRect: screen.frame, styleMask: .borderless,
                                       backing: .buffered, defer: false, screen: screen)
        win.level = .screenSaver
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.mode = mode
        view.screenWindows = windows
        view.screenFrame = screen.frame
        view.onFinish = { [weak self] rect, scWindow in
            self?.finish(Result(screen: screen, rect: rect, window: scWindow))
        }
        view.onCancel = { [weak self] in self?.finish(nil) }
        win.contentView = view

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        win.makeFirstResponder(view)
        NSCursor.crosshair.push()

        // Circuit breaker: Escape always tears the overlay down.
        // Local monitor swallows Escape while the app is key (returns nil so it
        // isn't beeped/forwarded)...
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.finish(nil); return nil }
            return event
        }
        // ...and a global monitor catches Escape even if focus ended up elsewhere,
        // so the overlay can never get "stuck" with no way out.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.finish(nil) }
        }

        self.window = win
    }

    private func finish(_ result: Result?) {
        NSCursor.pop()
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
        window?.orderOut(nil)
        window = nil
        let done = completion
        completion = nil
        done?(result)
    }
}

/// Flipped (top-left origin) NSView that renders the dim + selection chrome.
private final class SelectionView: NSView {
    var mode: RegionSelectionOverlay.Mode = .region
    var screenWindows: [SCWindow] = []
    var screenFrame: CGRect = .zero
    var onFinish: ((CGRect, SCWindow?) -> Void)?
    var onCancel: (() -> Void)?

    private var dragStart: CGPoint?
    private var dragRect: CGRect = .zero
    private var hoveredWindow: SCWindow?
    private var hoveredRect: CGRect = .zero

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        guard mode == .region else { return }
        dragStart = convert(event.locationInWindow, from: nil)
        dragRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .region, let start = dragStart else { return }
        let p = convert(event.locationInWindow, from: nil)
        dragRect = CGRect(x: min(start.x, p.x), y: min(start.y, p.y),
                          width: abs(p.x - start.x), height: abs(p.y - start.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if mode == .window {
            onFinish?(hoveredRect, hoveredWindow); return
        }
        if dragRect.width >= 4, dragRect.height >= 4 {
            onFinish?(dragRect, nil)
        } else {
            onCancel?()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard mode == .window else { return }
        updateHoveredWindow(at: event.locationInWindow)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect], owner: self))
    }

    private func updateHoveredWindow(at windowPoint: CGPoint) {
        // Convert the view (top-left) point to global AppKit (bottom-left) space.
        let local = convert(windowPoint, from: nil)
        let global = CGPoint(x: screenFrame.minX + local.x,
                             y: screenFrame.maxY - local.y)
        let hit = screenWindows.first { $0.frame.contains(global) }
        hoveredWindow = hit
        if let f = hit?.frame {
            hoveredRect = CGRect(x: f.minX - screenFrame.minX,
                                 y: screenFrame.maxY - f.maxY,
                                 width: f.width, height: f.height)
        } else {
            hoveredRect = .zero
        }
        needsDisplay = true
    }

    // MARK: Draw

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0, alpha: 0.28).setFill()
        bounds.fill()

        let sel = mode == .window ? hoveredRect : dragRect
        guard sel.width > 0, sel.height > 0 else { return }

        // Punch a clear hole over the selection (copy compositing = replace).
        if let gc = NSGraphicsContext.current {
            gc.compositingOperation = .copy
            NSColor.clear.setFill()
            NSBezierPath(rect: sel).fill()
            gc.compositingOperation = .sourceOver
        }

        // Accent border + size label.
        let accent = AccentPalette.signalRed.nsColor
        accent.setStroke()
        let border = NSBezierPath(rect: sel.insetBy(dx: -0.5, dy: -0.5))
        border.lineWidth = 1.5
        border.stroke()

        let label = "\(Int(sel.width)) × \(Int(sel.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: attrs)
        let pad: CGFloat = 6
        let badge = CGRect(x: sel.minX, y: max(0, sel.minY - size.height - pad * 2 - 4),
                           width: size.width + pad * 2, height: size.height + pad)
        accent.setFill()
        NSBezierPath(roundedRect: badge, xRadius: 4, yRadius: 4).fill()
        label.draw(at: CGPoint(x: badge.minX + pad, y: badge.minY + pad / 2), withAttributes: attrs)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }
}

/// Borderless windows can't become key by default, which breaks keyboard focus
/// (Escape) and reliable mouse routing for the overlay. Opt back in.
private final class KeyableOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private extension AccentPalette {
    var nsColor: NSColor {
        let hex = UInt32(rawValue.dropFirst(), radix: 16) ?? 0xd81f0d
        return NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                       green: CGFloat((hex >> 8) & 0xff) / 255,
                       blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}
