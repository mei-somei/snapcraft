import SwiftUI

/// Top-center floating bar: the active tool's color swatches and stroke sizes.
/// Transparent (no panel fill), per the design.
struct ContextualBar: View {
    @ObservedObject var viewModel: EditorViewModel
    @EnvironmentObject var settings: AppSettings

    private var swatches: [Color] {
        [settings.accent.color, Theme.swatchBlack, Theme.swatchGreen, Theme.swatchYellow, Theme.swatchWhite]
    }

    var body: some View {
        HStack(spacing: 13) {
            HStack(spacing: 8) {
                ForEach(Array(swatches.enumerated()), id: \.offset) { _, c in
                    ColorSwatch(color: c,
                                selected: viewModel.color.approxEquals(c),
                                accent: settings.accent.color) {
                        viewModel.color = c
                    }
                }
            }

            Rectangle().fill(Color(hex: 0x14120e, alpha: 0.14)).frame(width: 1, height: 22)

            HStack(spacing: 9) {
                ForEach(StrokeWidth.allCases) { sw in
                    StrokeDot(width: sw,
                              selected: viewModel.strokeWidth == sw,
                              accent: settings.accent.color) {
                        viewModel.strokeWidth = sw
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct ColorSwatch: View {
    let color: Color
    let selected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle().stroke(color == Theme.swatchWhite ? Color(hex: 0xd8d4ca) : .clear, lineWidth: 1)
                )
                .overlay(
                    Circle().stroke(selected ? accent : .clear, lineWidth: 1.5)
                        .padding(-3.5)
                        .overlay(Circle().stroke(Theme.canvas, lineWidth: 2).padding(-2))
                        .opacity(selected ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct StrokeDot: View {
    let width: StrokeWidth
    let selected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(selected ? accent : Theme.toolIcon)
                .frame(width: width.dotDiameter, height: width.dotDiameter)
                .overlay(
                    Circle().stroke(accent, lineWidth: 1.5).padding(-3)
                        .opacity(selected ? 1 : 0)
                )
                .frame(width: 22, height: 22)   // even hit target
        }
        .buttonStyle(.plain)
    }
}

private extension Color {
    /// Rough equality for swatch-selection highlighting.
    func approxEquals(_ other: Color) -> Bool {
        NSColor(self).usingColorSpace(.sRGB)?.cgColor == NSColor(other).usingColorSpace(.sRGB)?.cgColor
    }
}
