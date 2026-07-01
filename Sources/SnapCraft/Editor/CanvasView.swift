import SwiftUI

/// The captured image with live annotation interaction. Sized to
/// `imageSize * zoom`; pointer coordinates map back to image space by dividing
/// by `zoom`, so every annotation is stored resolution-independently.
struct CanvasView: View {
    @ObservedObject var viewModel: EditorViewModel
    let actions: EditorActions

    // Live interaction state.
    @State private var draftID: Annotation.ID?
    @State private var lastPoint: CGPoint?
    @State private var marqueeRect: CGRect?       // crop / ocr preview
    @State private var editingTextID: Annotation.ID?
    @FocusState private var textFocused: Bool

    // Inline rename of the capture caption (double-click).
    @State private var editingCaption = false
    @FocusState private var captionFocused: Bool

    private var zoom: CGFloat { viewModel.zoom }
    private var imageSize: CGSize { viewModel.capture.size }
    private var displaySize: CGSize {
        CGSize(width: imageSize.width * zoom, height: imageSize.height * zoom)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: viewModel.capture.image)
                .resizable()
                .frame(width: displaySize.width, height: displaySize.height)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            if viewModel.showAnnotations {
                AnnotationLayer(image: viewModel.capture.image,
                                imageSize: imageSize,
                                annotations: viewModel.annotations)
                    .frame(width: displaySize.width, height: displaySize.height)
                    .allowsHitTesting(false)
            }

            selectionChrome
            marqueeOverlay
            textEditor
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(Theme.imageShadow)
        .overlay(alignment: .topLeading) { caption }
        .contentShape(Rectangle())
        .gesture(drawGesture)
    }

    // MARK: Caption

    @ViewBuilder
    private var caption: some View {
        Group {
            if editingCaption {
                TextField("Name", text: Binding(
                    get: { viewModel.capture.caption },
                    set: { viewModel.capture.caption = $0 }))
                    .textFieldStyle(.plain)
                    .font(Theme.font(12, .medium))
                    .foregroundStyle(Theme.text)
                    .focused($captionFocused)
                    .frame(width: 360, alignment: .leading)
                    .onSubmit { editingCaption = false; viewModel.isTextEditing = false }
            } else {
                Text("\(viewModel.capture.caption)\(viewModel.annotations.isEmpty ? "" : " · edited")")
                    .font(Theme.font(12, .medium))
                    .foregroundStyle(Theme.textMuted)
                    // Double-click the caption to rename the capture.
                    .onTapGesture(count: 2) {
                        editingCaption = true
                        captionFocused = true
                        viewModel.isTextEditing = true
                    }
            }
        }
        .offset(y: -26)
    }

    // MARK: Selection chrome (bounding box of the selected annotation)

    @ViewBuilder
    private var selectionChrome: some View {
        if let id = viewModel.selectedID,
           let a = viewModel.annotations.first(where: { $0.id == id }) {
            let r = boundingRect(of: a).scaled(zoom)
            RoundedRectangle(cornerRadius: 3)
                .stroke(viewModel.color, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: r.width + 12, height: r.height + 12)
                .offset(x: r.minX - 6, y: r.minY - 6)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var marqueeOverlay: some View {
        if let r = marqueeRect?.scaled(zoom) {
            Rectangle()
                .stroke(viewModel.tool == .ocr ? Theme.swatchGreen : viewModel.color,
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .background(Color.white.opacity(0.08))
                .frame(width: r.width, height: r.height)
                .offset(x: r.minX, y: r.minY)
                .allowsHitTesting(false)
        }
    }

    // MARK: Inline text editing

    @ViewBuilder
    private var textEditor: some View {
        if let id = editingTextID,
           let idx = viewModel.annotations.firstIndex(where: { $0.id == id }) {
            let a = viewModel.annotations[idx]
            let p = a.start.scaled(zoom)
            let isTooltip = a.kind == .tooltip
            let field = TextField(isTooltip ? "Tooltip" : "Text", text: Binding(
                get: { viewModel.annotations.first(where: { $0.id == id })?.text ?? "" },
                set: { newValue in viewModel.update(id: id) { $0.text = newValue } }))
                .textFieldStyle(.plain)
                .font(.system(size: isTooltip ? max(13, a.strokeWidth * 2.0) * zoom
                                                : max(14, a.strokeWidth * 2.4) * zoom,
                              weight: isTooltip ? .medium : .semibold))
                .foregroundStyle(isTooltip ? .white : a.color)
                .focused($textFocused)
            // Tooltips type inside the colored bubble; plain text sits bare.
            Group {
                if isTooltip {
                    field
                        .frame(minWidth: 60, maxWidth: 260 * zoom, alignment: .leading)
                        .padding(.horizontal, 10 * zoom)
                        .padding(.vertical, 7 * zoom)
                        .background(RoundedRectangle(cornerRadius: 8 * zoom).fill(a.color))
                } else {
                    field.frame(minWidth: 60, alignment: .leading)
                }
            }
                .offset(x: p.x, y: p.y)
                .onSubmit { commitTextEditing() }
                // Escape ends typing and switches to Select so the text box can
                // be moved right away. The focused field handles Escape before
                // the editor's global shortcut, so we commit here too.
                .onExitCommand { commitTextEditing(); viewModel.select(.select) }
        }
    }

    // MARK: Gesture

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in onChanged(value) }
            .onEnded { value in onEnded(value) }
    }

    private func toImage(_ p: CGPoint) -> CGPoint {
        CGPoint(x: max(0, min(imageSize.width, p.x / zoom)),
                y: max(0, min(imageSize.height, p.y / zoom)))
    }

    private func onChanged(_ value: DragGesture.Value) {
        let p = toImage(value.location)

        // Begin a drag.
        if draftID == nil && lastPoint == nil && marqueeRect == nil {
            // Clicking elsewhere finishes any open text box; discard it if empty.
            commitTextEditing()
            beginDrag(at: p, start: toImage(value.startLocation))
            lastPoint = p
            return
        }

        switch viewModel.tool {
        case .select:
            if let id = draftID, let last = lastPoint {
                let dx = p.x - last.x, dy = p.y - last.y
                viewModel.update(id: id) { translate(&$0, dx: dx, dy: dy) }
            }
        case .pen:
            if let id = draftID {
                viewModel.update(id: id) { $0.points.append(p) }
            }
        case .crop, .ocr:
            if let start = lastPoint == nil ? nil : toImage(value.startLocation) {
                marqueeRect = CGRect(x: min(start.x, p.x), y: min(start.y, p.y),
                                     width: abs(p.x - start.x), height: abs(p.y - start.y))
            }
        case .text, .tooltip, .step:
            break // single-click placement
        default:
            if let id = draftID {
                viewModel.update(id: id) { $0.end = p }
            }
        }
        lastPoint = p
    }

    private func beginDrag(at p: CGPoint, start: CGPoint) {
        switch viewModel.tool {
        case .select:
            viewModel.selectedID = hitTest(p)
            if viewModel.selectedID != nil { viewModel.checkpoint() }
            draftID = viewModel.selectedID

        case .crop, .ocr:
            marqueeRect = CGRect(origin: p, size: .zero)

        case .text, .tooltip:
            var a = Annotation(kind: viewModel.tool == .tooltip ? .tooltip : .text,
                               color: viewModel.color,
                               strokeWidth: viewModel.strokeWidth.rawValue)
            a.start = p
            viewModel.add(a)
            viewModel.selectedID = a.id
            editingTextID = a.id
            viewModel.isTextEditing = true
            draftID = a.id
            // Focus on the next runloop tick so the new TextField exists first;
            // setting it synchronously (after commitTextEditing cleared focus in
            // the same cycle) intermittently fails to focus the new box.
            DispatchQueue.main.async { textFocused = true }

        case .step:
            var a = Annotation(kind: .step, color: viewModel.color,
                               strokeWidth: viewModel.strokeWidth.rawValue)
            a.start = p
            a.stepNumber = viewModel.nextStepNumber
            viewModel.add(a)
            draftID = a.id

        default:
            var a = Annotation(kind: kind(for: viewModel.tool), color: viewModel.color,
                               strokeWidth: viewModel.strokeWidth.rawValue)
            a.start = start
            a.end = p
            if a.kind == .pen { a.points = [start, p] }
            viewModel.add(a)
            draftID = a.id
        }
    }

    private func onEnded(_ value: DragGesture.Value) {
        switch viewModel.tool {
        case .crop:
            if let r = marqueeRect, r.width > 8, r.height > 8 { applyCrop(r) }
        case .ocr:
            if let r = marqueeRect, r.width > 8, r.height > 8 { actions.runOCR(r) }
        default:
            break
        }
        draftID = nil
        lastPoint = nil
        marqueeRect = nil
    }

    // MARK: Helpers

    /// Ends inline text editing. An untyped (empty) text box is removed so
    /// abandoned clicks don't leave stray placeholders behind.
    private func commitTextEditing() {
        defer { editingTextID = nil; textFocused = false; viewModel.isTextEditing = false }
        guard let id = editingTextID,
              let a = viewModel.annotations.first(where: { $0.id == id }) else { return }
        if a.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.annotations.removeAll { $0.id == id }
            if viewModel.selectedID == id { viewModel.selectedID = nil }
        }
    }

    private func kind(for tool: Tool) -> Annotation.Kind {
        switch tool {
        case .arrow:  return .arrow
        case .doubleArrow: return .doubleArrow
        case .line:   return .line
        case .shape:  return .shape
        case .pen:    return .pen
        case .marker: return .marker
        case .blur:   return .blur
        default:      return .arrow
        }
    }

    private func translate(_ a: inout Annotation, dx: CGFloat, dy: CGFloat) {
        a.start.x += dx; a.start.y += dy
        a.end.x += dx;   a.end.y += dy
        a.points = a.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
    }

    private func boundingRect(of a: Annotation) -> CGRect {
        switch a.kind {
        case .pen:
            guard let first = a.points.first else { return a.rect }
            var r = CGRect(origin: first, size: .zero)
            for p in a.points { r = r.union(CGRect(origin: p, size: .zero)) }
            return r
        case .text, .step:
            return CGRect(x: a.start.x - 14, y: a.start.y - 14, width: 60, height: 28)
        case .tooltip:
            return CGRect(x: a.start.x - 6, y: a.start.y - 6, width: 120, height: 44)
        default:
            return a.rect
        }
    }

    private func hitTest(_ p: CGPoint) -> Annotation.ID? {
        // Topmost annotation whose padded bounds contain the point.
        for a in viewModel.annotations.reversed() {
            if boundingRect(of: a).insetBy(dx: -10, dy: -10).contains(p) { return a.id }
        }
        return nil
    }

    private func applyCrop(_ rect: CGRect) {
        let img = viewModel.capture.image
        let scale = (img.representations.first as? NSBitmapImageRep).map {
            CGFloat($0.pixelsWide) / max(img.size.width, 1)
        } ?? 2
        guard let cropped = ScreenCaptureService.crop(img, to: rect, scale: scale) else { return }
        viewModel.checkpoint()
        // Shift annotations into the new origin.
        viewModel.annotations = viewModel.annotations.map { a in
            var b = a
            translate(&b, dx: -rect.minX, dy: -rect.minY)
            return b
        }
        viewModel.capture = CapturedImage(image: cropped, caption: viewModel.capture.caption)
        viewModel.select(.select)
    }
}
