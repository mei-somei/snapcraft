import Foundation
import Carbon.HIToolbox

/// The four hot-key-bindable capture actions.
enum CaptureKind: String, CaseIterable, Identifiable, Codable {
    case selectedArea
    case window
    case fullscreen
    case pin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selectedArea: return "Capture selected area"
        case .window:       return "Capture window"
        case .fullscreen:   return "Capture fullscreen"
        case .pin:          return "Pin last capture to screen"
        }
    }
}

/// A user-customizable keyboard shortcut. Stores both the Carbon virtual key
/// code (for global registration) and a display label (for the keycap chips).
struct KeyCombo: Codable, Equatable {
    var command = false
    var shift   = false
    var option  = false
    var control = false
    var keyCode: UInt32
    var display: String   // the non-modifier keycap, e.g. "4" or "P"

    /// Modifier keycaps in macOS display order, then the key label.
    var keyCaps: [String] {
        var caps: [String] = []
        if control { caps.append("⌃") }
        if option  { caps.append("⌥") }
        if shift   { caps.append("⇧") }
        if command { caps.append("⌘") }
        caps.append(display)
        return caps
    }

    /// Carbon modifier mask for `RegisterEventHotKey`.
    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if command { m |= UInt32(cmdKey) }
        if shift   { m |= UInt32(shiftKey) }
        if option  { m |= UInt32(optionKey) }
        if control { m |= UInt32(controlKey) }
        return m
    }
}

extension KeyCombo {
    /// Default bindings. macOS reserves ⌘⇧3/4/5/6 for its own screen capture,
    /// so those can't be registered as global hot keys — we use Option-Command
    /// instead (same 3/4/5 digit meaning, but conflict-free).
    static let defaults: [CaptureKind: KeyCombo] = [
        .fullscreen:   KeyCombo(command: true, option: true,
                                keyCode: UInt32(kVK_ANSI_3), display: "3"),
        .selectedArea: KeyCombo(command: true, option: true,
                                keyCode: UInt32(kVK_ANSI_4), display: "4"),
        .window:       KeyCombo(command: true, option: true,
                                keyCode: UInt32(kVK_ANSI_5), display: "5"),
        .pin:          KeyCombo(command: true, option: true,
                                keyCode: UInt32(kVK_ANSI_P), display: "P"),
    ]

    /// Map a recorded NSEvent keyCode to its display label, where known.
    static func label(forKeyCode code: UInt16) -> String? {
        keyCodeLabels[Int(code)]
    }

    /// Minimal virtual-keycode → label table covering the keys this app binds
    /// plus common alternatives a user might choose in the recorder.
    static let keyCodeLabels: [Int: String] = [
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_Space: "␣", kVK_Return: "⏎", kVK_Escape: "⎋",
    ]
}
