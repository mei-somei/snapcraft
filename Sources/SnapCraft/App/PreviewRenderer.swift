import SwiftUI
import AppKit

/// Renders the Editor and Settings screens to PNGs using a synthetic capture,
/// so the design can be verified without a live screenshot. Invoked via
/// `SnapCraft --render-previews <dir>`.
@MainActor
enum PreviewRenderer {

    static func run(outputDirectory: String) {
        _ = NSApplication.shared
        let dir = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let settings = AppSettings.shared
        let capture = CapturedImage(image: syntheticCapture(), caption: "Capture 2025-06-27 at 09.41.png")
        let vm = EditorViewModel(capture: capture, accent: settings.accent.color)
        vm.annotations = sampleAnnotations(accent: settings.accent.color)

        let noop = EditorActions(copy: {}, save: {}, saveAs: {}, pin: {},
                                 openSettings: {}, runOCR: { _ in })

        let editor = EditorView(viewModel: vm, actions: noop)
            .environmentObject(settings)
            .frame(width: 1180, height: 760)
        write(editor, to: dir.appendingPathComponent("editor.png"))

        let settingsView = SettingsView()
            .environmentObject(settings)
            .frame(width: 880, height: 640)
        write(settingsView, to: dir.appendingPathComponent("settings.png"))

        // Settings content column (sections live inside a ScrollView in the real
        // window, which ImageRenderer cannot snapshot — render them directly).
        let settingsContent = VStack(alignment: .leading, spacing: 24) {
            ShortcutsSection()
            SavingSection()
            BehaviorSection()
            AppearanceSection()
        }
        .frame(width: 660, alignment: .leading)
        .padding(30)
        .background(Theme.surface)
        .environmentObject(settings)
        write(settingsContent, to: dir.appendingPathComponent("settings-content.png"))

        // The actual export/composite path (image + annotations baked in) — this
        // is what Copy/Save produce and what the live canvas shows.
        let composite = Exporter.composite(capture: capture, annotations: vm.annotations)
        if let tiff = composite.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("composite.png"))
        }

        // The canvas as the live editor draws it (no ScrollView, which
        // ImageRenderer cannot snapshot), on the canvas backdrop.
        let canvasOnly = ZStack {
            Theme.canvas
            DotGridView()
            CanvasView(viewModel: vm, actions: noop).padding(60)
        }
        .environmentObject(settings)
        .frame(width: 1060, height: 700)
        write(canvasOnly, to: dir.appendingPathComponent("canvas.png"))

        print("✓ Rendered previews to \(dir.path)")
        exit(0)
    }

    private static func write<V: View>(_ view: V, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    // MARK: Synthetic content

    /// A light placeholder image standing in for "the user's captured pixels."
    private static func syntheticCapture() -> NSImage {
        let size = NSSize(width: 1000, height: 600)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(srgbRed: 0.985, green: 0.985, blue: 0.99, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()

        // Mock sidebar.
        NSColor(srgbRed: 0.98, green: 0.976, blue: 0.984, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 196, height: 600).fill()

        // Mock content bars.
        NSColor(white: 0.9, alpha: 1).setFill()
        for i in 0..<5 {
            NSBezierPath(roundedRect: NSRect(x: 240, y: CGFloat(120 + i * 70), width: 680, height: 44),
                         xRadius: 8, yRadius: 8).fill()
        }
        NSColor(white: 0.86, alpha: 1).setFill()
        for i in 0..<5 {
            NSBezierPath(roundedRect: NSRect(x: 24, y: CGFloat(140 + i * 46), width: 150, height: 20),
                         xRadius: 5, yRadius: 5).fill()
        }
        image.unlockFocus()
        return image
    }

    /// One of each annotation kind to exercise the renderer.
    private static func sampleAnnotations(accent: Color) -> [Annotation] {
        var arrow = Annotation(kind: .arrow, color: accent, strokeWidth: 6)
        arrow.start = CGPoint(x: 700, y: 80); arrow.end = CGPoint(x: 560, y: 150)

        var step1 = Annotation(kind: .step, color: accent, strokeWidth: 6)
        step1.start = CGPoint(x: 240, y: 140); step1.stepNumber = 1
        var step2 = Annotation(kind: .step, color: accent, strokeWidth: 6)
        step2.start = CGPoint(x: 700, y: 140); step2.stepNumber = 2

        var marker = Annotation(kind: .marker, color: Theme.swatchYellow, strokeWidth: 6)
        marker.start = CGPoint(x: 280, y: 255); marker.end = CGPoint(x: 360, y: 281)

        var blur = Annotation(kind: .blur, color: accent, strokeWidth: 6)
        blur.start = CGPoint(x: 247, y: 151); blur.end = CGPoint(x: 697, y: 184)

        var text = Annotation(kind: .text, color: accent, strokeWidth: 7)
        text.start = CGPoint(x: 250, y: 360); text.text = "Check this"

        return [blur, marker, arrow, step1, step2, text]
    }
}
