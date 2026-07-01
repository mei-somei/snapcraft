import AppKit
import SwiftUI

/// Top-level coordinator. Owns the settings store, capture pipeline, global
/// hot-key registrar, and window manager, and wires the editor's export/OCR
/// actions back to the native services.
@MainActor
final class AppController: ObservableObject {

    let settings = AppSettings.shared
    private let capture: CaptureController
    private let hotKeys = HotKeyManager()
    private let windows = WindowManager()

    /// Most recent editor, used by the "pin last capture" hot key.
    private weak var lastEditor: EditorViewModel?

    init() {
        capture = CaptureController(settings: settings)
        capture.onCapture = { [weak self] in self?.presentEditor(for: $0) }

        hotKeys.onTrigger = { [weak self] kind in self?.handle(kind) }
        hotKeys.register(settings.shortcuts)
        settings.onShortcutsChanged = { [weak self] in
            guard let self else { return }
            self.hotKeys.register(self.settings.shortcuts)
        }
    }

    // MARK: Menu / hot-key entry points

    func handle(_ kind: CaptureKind) {
        if kind == .pin { pinLastCapture(); return }
        capture.capture(kind)
    }

    func openSettings() { windows.openSettings(settings: settings) }

    // MARK: Editor presentation

    private func presentEditor(for capture: CapturedImage) {
        let inPlaceFrame = capture.screenFrame
        let vm = EditorViewModel(capture: capture, accent: settings.accent.color,
                                 inPlace: inPlaceFrame != nil)
        lastEditor = vm

        // The floating in-place layer dismisses itself once the user copies or
        // saves; the standard editor stays open.
        weak var editorWindow: NSWindow?
        let dismissInPlace: () -> Void = { [weak self] in
            guard inPlaceFrame != nil, let window = editorWindow else { return }
            self?.windows.dismiss(window)
        }

        let actions = EditorActions(
            copy: { [weak self, weak vm] in self?.copy(vm); dismissInPlace() },
            save: { [weak self, weak vm] in self?.save(vm); dismissInPlace() },
            saveAs: { [weak self, weak vm] in self?.saveAs(vm) },
            pin: { [weak self, weak vm] in self?.pin(vm) },
            openSettings: { [weak self] in self?.openSettings() },
            runOCR: { [weak self, weak vm] rect in self?.runOCR(vm, rect: rect) }
        )
        editorWindow = windows.openEditor(viewModel: vm, settings: settings,
                                          actions: actions, inPlaceFrame: inPlaceFrame)
    }

    // MARK: Export actions

    private func copy(_ vm: EditorViewModel?) {
        guard let vm else { return }
        Exporter.copyToClipboard(capture: vm.capture, annotations: vm.annotations)
        vm.statusText = "Copied to clipboard"
    }

    private func save(_ vm: EditorViewModel?) {
        guard let vm else { return }
        if let url = Exporter.saveToFile(capture: vm.capture, annotations: vm.annotations,
                                         settings: settings) {
            vm.statusText = "Saved · \(url.lastPathComponent)"
        } else {
            vm.statusText = "Save failed"
        }
    }

    private func saveAs(_ vm: EditorViewModel?) {
        guard let vm else { return }
        Exporter.saveWithPanel(capture: vm.capture, annotations: vm.annotations, settings: settings)
    }

    private func pin(_ vm: EditorViewModel?) {
        guard let vm else { return }
        let composite = Exporter.composite(capture: vm.capture, annotations: vm.annotations)
        windows.openPin(image: composite)
    }

    private func pinLastCapture() {
        guard let vm = lastEditor else { return }
        pin(vm)
    }

    // MARK: OCR

    private func runOCR(_ vm: EditorViewModel?, rect: CGRect) {
        guard let vm else { return }
        let img = vm.capture.image
        let scale = pixelScale(img)
        guard let region = ScreenCaptureService.crop(img, to: rect, scale: scale) else { return }
        vm.statusText = "Extracting text…"
        Task {
            let text = await OCRService.recognizeText(in: region)
            if text.isEmpty {
                vm.statusText = "No text found"
            } else {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
                vm.statusText = "Text copied · \(text.count) chars"
            }
        }
    }

    private func pixelScale(_ image: NSImage) -> CGFloat {
        guard let rep = image.representations.first as? NSBitmapImageRep, image.size.width > 0
        else { return 2 }
        return CGFloat(rep.pixelsWide) / image.size.width
    }
}
