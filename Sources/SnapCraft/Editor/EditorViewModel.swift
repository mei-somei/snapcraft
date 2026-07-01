import SwiftUI

/// Owns the editable state of one capture: the annotation list, undo/redo
/// stacks, the active tool, and the current stroke style. Geometry is in image
/// coordinate space; the canvas maps to screen space via `zoom`.
@MainActor
final class EditorViewModel: ObservableObject {

    @Published var capture: CapturedImage

    /// When true the editor is shown as an in-place layer the exact size of the
    /// captured region; the image fills the window 1:1 and only the tool
    /// clusters float on top.
    let inPlace: Bool

    @Published var tool: Tool = .arrow
    @Published var color: Color
    @Published var strokeWidth: StrokeWidth = .thin

    @Published var annotations: [Annotation] = []
    @Published var selectedID: Annotation.ID?

    /// True while an inline text box or the caption is being typed into, so the
    /// single-key tool shortcuts don't steal keystrokes from the field.
    @Published var isTextEditing = false

    @Published var zoom: CGFloat = 0.9
    @Published var showGrid = true
    @Published var showAnnotations = true   // demo overlay toggle

    /// Status line shown bottom-right (e.g. transient OCR / copy feedback).
    @Published var statusText = "Ready · ⌘C to copy"

    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []

    init(capture: CapturedImage, accent: Color, inPlace: Bool = false) {
        self.capture = capture
        self.color = accent
        self.inPlace = inPlace
        if inPlace { self.zoom = 1.0 }   // 1:1 so the image fills the region exactly
    }

    // MARK: Tool / style

    func select(_ tool: Tool) {
        self.tool = tool
        if tool != .select { selectedID = nil }
    }

    // MARK: Annotation mutation (each commits an undo checkpoint)

    /// Next auto-incrementing badge number for the step tool.
    var nextStepNumber: Int {
        annotations.filter { $0.kind == .step }.count + 1
    }

    func add(_ annotation: Annotation) {
        checkpoint()
        annotations.append(annotation)
    }

    func update(id: Annotation.ID, _ transform: (inout Annotation) -> Void) {
        guard let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        transform(&annotations[idx])
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        checkpoint()
        annotations.removeAll { $0.id == id }
        selectedID = nil
    }

    /// Snapshot current state for undo. Call *before* a mutation.
    func checkpoint() {
        undoStack.append(annotations)
        redoStack.removeAll()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = prev
        selectedID = nil
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        selectedID = nil
    }

    // MARK: Zoom

    func zoomIn()  { setZoom(zoom + 0.1) }
    func zoomOut() { setZoom(zoom - 0.1) }
    func zoomToFit() { zoom = 0.9 }

    /// Absolute zoom, clamped to the supported range. Used by trackpad pinch.
    func setZoom(_ z: CGFloat) { zoom = min(max(z, 0.2), 4.0) }
    var zoomPercent: Int { Int((zoom * 100).rounded()) }
}
