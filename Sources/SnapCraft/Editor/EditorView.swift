import SwiftUI

/// The post-capture editor: a gridded canvas with the screenshot centered and
/// transparent floating control clusters overlaying it.
struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel
    let actions: EditorActions
    @EnvironmentObject var settings: AppSettings

    /// Zoom level captured at the start of a trackpad pinch.
    @State private var pinchBaseZoom: CGFloat?

    var body: some View {
        ZStack {
            // Whiteboard backdrop (dot grid over the canvas tone) in both the
            // standard editor and the in-place layer, so the screenshot always
            // floats on the whiteboard.
            Theme.canvas.ignoresSafeArea()
            if viewModel.showGrid { DotGridView().ignoresSafeArea() }

            // Centered when it fits, scrollable when larger than the window.
            GeometryReader { geo in
                ScrollView([.horizontal, .vertical]) {
                    CanvasView(viewModel: viewModel, actions: actions)
                        .padding(viewModel.inPlace ? 48 : 80)
                        .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                }
            }
        }
        // Trackpad pinch-to-zoom (scales relative to where the pinch began).
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    let base = pinchBaseZoom ?? viewModel.zoom
                    if pinchBaseZoom == nil { pinchBaseZoom = base }
                    viewModel.setZoom(base * value.magnification)
                }
                .onEnded { _ in pinchBaseZoom = nil }
        )
        // Floating clusters pinned to their anchors.
        .overlay(alignment: .topLeading) {
            TopLeftCluster(viewModel: viewModel, actions: actions)
                // Clear the macOS traffic lights when shown as an in-place layer.
                .padding(.leading, viewModel.inPlace ? 78 : 22).padding(.top, 18)
        }
        .overlay(alignment: .top) {
            ContextualBar(viewModel: viewModel)
                .padding(.top, 18)
        }
        .overlay(alignment: .leading) {
            ToolStrip(viewModel: viewModel, actions: actions)
                .padding(.leading, 40)
        }
        .overlay(alignment: .bottomLeading) {
            ZoomPill(viewModel: viewModel).padding(18)
        }
        .overlay(alignment: .bottomTrailing) {
            StatusPill(viewModel: viewModel).padding(18)
        }
        .background(KeyCommands(viewModel: viewModel, actions: actions))
        .preferredColorScheme(settings.theme.colorScheme)
        .frame(minWidth: viewModel.inPlace ? nil : 760,
               minHeight: viewModel.inPlace ? nil : 520)
    }
}

/// Hidden helper hosting the editor's keyboard shortcuts (⌘C / ⌘Z / ⌘⇧Z / ⌫).
private struct KeyCommands: View {
    @ObservedObject var viewModel: EditorViewModel
    let actions: EditorActions

    var body: some View {
        ZStack {
            Button("") { actions.copy() }.keyboardShortcut("c", modifiers: .command)
            Button("") { viewModel.undo() }.keyboardShortcut("z", modifiers: .command)
            Button("") { viewModel.redo() }.keyboardShortcut("z", modifiers: [.command, .shift])
            Button("") { actions.save() }.keyboardShortcut("s", modifiers: .command)
            Button("") { viewModel.deleteSelected() }.keyboardShortcut(.delete, modifiers: [])

            // Escape quits the active tool and drops back to Select (move), so
            // you can immediately reposition what you just drew. While typing,
            // the focused text box's own Escape handler runs first (it commits
            // the text, then switches to Select) — see CanvasView.
            Button("") { viewModel.select(.select) }
                .keyboardShortcut(.escape, modifiers: [])

            // Single-key tool shortcuts (V, A, T, …). Disabled while typing so
            // they don't steal keystrokes from a text box or the caption.
            ForEach(Tool.allCases) { tool in
                Button("") { viewModel.select(tool) }
                    .keyboardShortcut(KeyEquivalent(tool.shortcut), modifiers: [])
            }
            .disabled(viewModel.isTextEditing)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }
}
