import SwiftUI
import Combine

enum ThemeMode: String, CaseIterable, Identifiable {
    case light, dark, auto
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark:  return .dark
        case .auto:  return nil
        }
    }
}

enum FileFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"
    var id: String { rawValue }
    var fileExtension: String {
        switch self {
        case .png:  return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        }
    }
}

/// Persisted user preferences. Backed by `UserDefaults`; every mutation writes
/// through so the menu-bar process and any open windows stay consistent.
/// Hot-key changes notify `onShortcutsChanged` so the registrar can re-bind.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // Appearance
    @Published var accent: AccentPalette { didSet { persist() } }
    @Published var theme: ThemeMode { didSet { persist() } }

    // Saving
    @Published var saveLocation: String { didSet { persist() } }
    @Published var fileFormat: FileFormat { didSet { persist() } }
    @Published var copyToClipboard: Bool { didSet { persist() } }

    // Behavior
    @Published var launchAtLogin: Bool { didSet { persist() } }
    @Published var showInMenuBar: Bool { didSet { persist() } }
    @Published var captureSound: Bool { didSet { persist() } }

    // Capture shortcuts
    @Published var shortcuts: [CaptureKind: KeyCombo] {
        didSet { persist(); onShortcutsChanged?() }
    }

    /// Invoked after the shortcut table changes so the hot-key manager re-registers.
    var onShortcutsChanged: (() -> Void)?

    private let defaults = UserDefaults.standard
    private var loading = false

    private init() {
        let d = UserDefaults.standard
        accent = AccentPalette.from(d.string(forKey: K.accent) ?? AccentPalette.signalRed.rawValue)
        theme = ThemeMode(rawValue: d.string(forKey: K.theme) ?? "") ?? .auto
        saveLocation = d.string(forKey: K.saveLocation)
            ?? (NSHomeDirectory() as NSString).appendingPathComponent("Pictures/SnapCraft")
        fileFormat = FileFormat(rawValue: d.string(forKey: K.fileFormat) ?? "") ?? .png
        copyToClipboard = d.object(forKey: K.copyToClipboard) as? Bool ?? true
        launchAtLogin = d.object(forKey: K.launchAtLogin) as? Bool ?? true
        showInMenuBar = d.object(forKey: K.showInMenuBar) as? Bool ?? true
        captureSound = d.object(forKey: K.captureSound) as? Bool ?? false

        // Reset persisted shortcuts when the default schema changes (e.g. old
        // builds stored macOS-reserved ⌘⇧4 combos that can't be registered).
        if d.integer(forKey: K.shortcutsVersion) >= Self.shortcutsVersion,
           let data = d.data(forKey: K.shortcuts),
           let decoded = try? JSONDecoder().decode([CaptureKind: KeyCombo].self, from: data) {
            shortcuts = decoded
        } else {
            shortcuts = KeyCombo.defaults
        }
    }

    /// Bump when `KeyCombo.defaults` changes to migrate stored bindings.
    private static let shortcutsVersion = 2

    /// Display path with the home directory collapsed to `~`.
    var saveLocationDisplay: String {
        let home = NSHomeDirectory()
        return saveLocation.hasPrefix(home)
            ? "~" + saveLocation.dropFirst(home.count)
            : saveLocation
    }

    private func persist() {
        guard !loading else { return }
        defaults.set(accent.rawValue, forKey: K.accent)
        defaults.set(theme.rawValue, forKey: K.theme)
        defaults.set(saveLocation, forKey: K.saveLocation)
        defaults.set(fileFormat.rawValue, forKey: K.fileFormat)
        defaults.set(copyToClipboard, forKey: K.copyToClipboard)
        defaults.set(launchAtLogin, forKey: K.launchAtLogin)
        defaults.set(showInMenuBar, forKey: K.showInMenuBar)
        defaults.set(captureSound, forKey: K.captureSound)
        if let data = try? JSONEncoder().encode(shortcuts) {
            defaults.set(data, forKey: K.shortcuts)
        }
        defaults.set(Self.shortcutsVersion, forKey: K.shortcutsVersion)
    }

    private enum K {
        static let accent = "accent"
        static let theme = "theme"
        static let saveLocation = "saveLocation"
        static let fileFormat = "fileFormat"
        static let copyToClipboard = "copyToClipboard"
        static let launchAtLogin = "launchAtLogin"
        static let showInMenuBar = "showInMenuBar"
        static let captureSound = "captureSound"
        static let shortcuts = "shortcuts"
        static let shortcutsVersion = "shortcutsVersion"
    }
}
