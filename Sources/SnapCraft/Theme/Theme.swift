import SwiftUI

/// Centralized design tokens lifted verbatim from the SnapCraft design handoff.
/// Every surface reads from here so the accent color (and future theming) flows
/// from a single source of truth.
enum Theme {

    // MARK: Neutrals (warm)
    static let surface       = Color(hex: 0xffffff)   // app surface
    static let canvas        = Color(hex: 0xefece5)   // editor canvas backdrop
    static let text          = Color(hex: 0x1a1814)   // primary text
    static let textSecondary = Color(hex: 0x56514a)   // secondary text
    static let textMuted     = Color(hex: 0x8a857a)   // muted text
    static let textFaint     = Color(hex: 0xa8a39a)   // faint / eyebrow text
    static let border        = Color(hex: 0xece9e1)   // hairline
    static let borderStrong  = Color(hex: 0xe3e0d8)   // stronger hairline
    static let chipFill      = Color(hex: 0xf3f1ea)   // keycap / chip fill
    static let chipBorder    = Color(hex: 0xe6e3da)   // keycap / chip border
    static let toolIcon      = Color(hex: 0x4a463e)   // resting tool icon
    static let toolIconOff   = Color(hex: 0xbdb8ac)   // disabled tool icon
    static let rowHairline   = Color(hex: 0xf1efe9)   // settings row separator
    static let sidebarBg     = Color(hex: 0xfcfbf9)   // settings sidebar
    static let toggleOff     = Color(hex: 0xdcd8ce)   // toggle off track

    // MARK: Contextual-bar swatches (annotation colors offered in the editor)
    static let swatchBlack  = Color(hex: 0x1a1814)
    static let swatchGreen  = Color(hex: 0x1d8a4f)
    static let swatchYellow = Color(hex: 0xf5b500)
    static let swatchWhite  = Color(hex: 0xffffff)

    // MARK: Radii
    enum Radius {
        static let control: CGFloat = 8    // buttons / tool tiles
        static let card: CGFloat    = 12   // cards
        static let chip: CGFloat    = 6    // keycaps / chips
        static let toggle: CGFloat  = 13   // toggle track
    }

    // MARK: Typography — Helvetica Neue stack per the handoff.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Helvetica Neue", size: size).weight(weight)
    }

    // MARK: Shadows
    static let pillShadow = ShadowToken(color: Color(hex: 0x14120e, alpha: 0.08),
                                        radius: 14, x: 0, y: 4)
    static let imageShadow = ShadowToken(color: Color(hex: 0x14120e, alpha: 0.22),
                                         radius: 70, x: 0, y: 24)

    // MARK: Dot grid (editor canvas overlay)
    static let gridDot   = Color(hex: 0x14120e, alpha: 0.11)
    static let gridSpacing: CGFloat = 26
    static let gridDotRadius: CGFloat = 1.3
}

struct ShadowToken {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func shadow(_ token: ShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}

// MARK: - Hex color helper

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
