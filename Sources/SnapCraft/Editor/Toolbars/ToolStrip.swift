import SwiftUI

/// The transparent vertical tool strip pinned to the left of the screenshot.
/// Active tool gets an accent fill + white icon; export actions sit below.
struct ToolStrip: View {
    @ObservedObject var viewModel: EditorViewModel
    let actions: EditorActions
    @EnvironmentObject var settings: AppSettings

    /// Tool groups separated by hairline dividers, mirroring the design order.
    private let groups: [[Tool]] = [
        [.select, .crop],
        [.shape, .arrow, .doubleArrow, .line, .pen, .marker, .text, .tooltip, .step],
        [.blur, .ocr],
    ]

    var body: some View {
        VStack(spacing: 3) {
            ForEach(Array(groups.enumerated()), id: \.offset) { idx, group in
                ForEach(group) { tool in
                    ToolTile(tool: tool,
                             isActive: viewModel.tool == tool,
                             accent: settings.accent.color) {
                        viewModel.select(tool)
                    }
                }
                if idx < groups.count - 1 { divider }
            }
            divider
            // Export actions
            ActionTile(symbol: "doc.on.doc", filled: true, accent: settings.accent.color,
                       title: "Copy to clipboard", action: actions.copy)
            ActionTile(symbol: "arrow.down.to.line", filled: false, accent: settings.accent.color,
                       title: "Save to file", action: actions.save)
            ActionTile(symbol: "pin", filled: false, accent: settings.accent.color,
                       title: "Pin to screen", action: actions.pin)
        }
        .padding(6)
        // Tinted frosted panel so the icons stay legible over any screenshot.
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.borderStrong, lineWidth: 1))
        )
        .shadow(Theme.pillShadow)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(hex: 0x14120e, alpha: 0.14))
            .frame(width: 22, height: 1)
            .padding(.vertical, 5)
    }
}

/// A 40×40 tool tile.
private struct ToolTile: View {
    let tool: Tool
    let isActive: Bool
    let accent: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.sfSymbol)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(isActive ? .white : Theme.toolIcon)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(isActive ? accent : (hovering ? Color(hex: 0x14120e, alpha: 0.06) : .clear))
                )
        }
        .buttonStyle(.plain)
        .help("\(tool.title) (\(tool.shortcutLabel))")
        .onHover { hovering = $0 }
    }
}

/// A 40×40 export-action tile (copy is the primary, accent-filled action).
private struct ActionTile: View {
    let symbol: String
    let filled: Bool
    let accent: Color
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(filled ? .white : Theme.toolIcon)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(filled ? accent : (hovering ? Color(hex: 0x14120e, alpha: 0.06) : .clear))
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { hovering = $0 }
    }
}
