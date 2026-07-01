import SwiftUI

/// Top-left cluster: brand wordmark + undo / redo / settings.
struct TopLeftCluster: View {
    @ObservedObject var viewModel: EditorViewModel
    let actions: EditorActions
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            Text("snapcraft")
                .font(Theme.font(17, .heavy))
                .tracking(-0.34)
                .foregroundStyle(settings.accent.color)
                .padding(.trailing, 4)

            GhostIcon(symbol: "arrow.uturn.backward", enabled: viewModel.canUndo,
                      help: "Undo") { viewModel.undo() }
            GhostIcon(symbol: "arrow.uturn.forward", enabled: viewModel.canRedo,
                      help: "Redo") { viewModel.redo() }
            GhostIcon(symbol: "gearshape", enabled: true,
                      help: "Settings", action: actions.openSettings)
        }
    }
}

private struct GhostIcon: View {
    let symbol: String
    let enabled: Bool
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(enabled ? Theme.toolIcon : Theme.toolIconOff)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(hovering && enabled ? Color(hex: 0x14120e, alpha: 0.06) : .clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
        .onHover { hovering = $0 }
    }
}

/// Bottom-left zoom pill (white chrome, hairline, soft shadow).
struct ZoomPill: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 2) {
            PillButton(symbol: "minus") { viewModel.zoomOut() }
            Text("\(viewModel.zoomPercent)%")
                .font(Theme.font(13, .semibold))
                .foregroundStyle(Theme.text)
                .frame(minWidth: 46)
            PillButton(symbol: "plus") { viewModel.zoomIn() }
            Rectangle().fill(Color(hex: 0xece9e1)).frame(width: 1, height: 18).padding(.horizontal, 2)
            PillButton(symbol: "arrow.up.left.and.arrow.down.right", help: "Fit") { viewModel.zoomToFit() }
        }
        .padding(4)
        .pillChrome()
    }
}

/// Bottom-right status pill.
struct StatusPill: View {
    @ObservedObject var viewModel: EditorViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(settings.accent.color).frame(width: 7, height: 7)
            Text(viewModel.statusText)
                .font(Theme.font(12.5, .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .pillChrome()
    }
}

private struct PillButton: View {
    let symbol: String
    var help: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.toolIcon)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hovering ? Color(hex: 0x14120e, alpha: 0.05) : .clear)
                )
        }
        .buttonStyle(.plain)
        .help(help ?? "")
        .onHover { hovering = $0 }
    }
}

private struct PillChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.borderStrong, lineWidth: 1))
            )
            .shadow(Theme.pillShadow)
    }
}

private extension View {
    func pillChrome() -> some View { modifier(PillChrome()) }
}
