import SwiftUI

/// The user-switchable annotation accent. Stored as a hex string in prefs so it
/// round-trips cleanly through UserDefaults.
enum AccentPalette: String, CaseIterable, Identifiable {
    case signalRed = "#d81f0d"   // default
    case blue      = "#1d4ed8"
    case nearBlack = "#1a1814"
    case orange    = "#ff5a1f"

    var id: String { rawValue }

    var color: Color {
        let hex = UInt32(rawValue.dropFirst(), radix: 16) ?? 0xd81f0d
        return Color(hex: hex)
    }

    /// 10% accent tint used for the settings active-nav background.
    var tint: Color {
        let hex = UInt32(rawValue.dropFirst(), radix: 16) ?? 0xd81f0d
        return Color(hex: hex, alpha: 0.10)
    }

    static func from(_ raw: String) -> AccentPalette {
        AccentPalette(rawValue: raw) ?? .signalRed
    }
}
