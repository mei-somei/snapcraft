import SwiftUI
import AppKit

/// CAPTURE SHORTCUTS card — each row is rebindable via `ShortcutRecorder`.
struct ShortcutsSection: View {
    @EnvironmentObject var settings: AppSettings
    private let order: [CaptureKind] = [.selectedArea, .window, .fullscreen, .pin]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow(text: "Capture shortcuts")
            SettingsCard {
                ForEach(Array(order.enumerated()), id: \.element) { idx, kind in
                    SettingsRow(title: kind.title) {
                        ShortcutRecorder(combo: binding(for: kind))
                    }
                    if idx < order.count - 1 { RowDivider() }
                }
            }
        }
    }

    private func binding(for kind: CaptureKind) -> Binding<KeyCombo> {
        Binding(
            get: { settings.shortcuts[kind] ?? KeyCombo.defaults[kind]! },
            set: { settings.shortcuts[kind] = $0 })
    }
}

/// SAVING card — location, format, copy-to-clipboard.
struct SavingSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow(text: "Saving")
            SettingsCard {
                SettingsRow(title: "Save location") {
                    HStack(spacing: 9) {
                        PathChip(path: settings.saveLocationDisplay, accent: settings.accent.color)
                        ChipButton(title: "Choose…") { chooseFolder() }
                    }
                }
                RowDivider()
                SettingsRow(title: "File format") {
                    Menu {
                        ForEach(FileFormat.allCases) { f in
                            Button(f.rawValue) { settings.fileFormat = f }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Text(settings.fileFormat.rawValue)
                                .font(Theme.font(13, .semibold)).foregroundStyle(Theme.text)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11)).foregroundStyle(Color(hex: 0x9a958a))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.borderStrong, lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                RowDivider()
                SettingsRow(title: "Copy to clipboard after capture",
                            subtitle: "Paste straight into chats and docs.") {
                    SnapToggle(isOn: $settings.copyToClipboard, accent: settings.accent.color)
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: settings.saveLocation)
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveLocation = url.path
        }
    }
}

/// BEHAVIOR card — launch at login, menu bar icon, capture sound.
struct BehaviorSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow(text: "Behavior")
            SettingsCard {
                SettingsRow(title: "Launch at login") {
                    SnapToggle(isOn: $settings.launchAtLogin, accent: settings.accent.color)
                }
                RowDivider()
                SettingsRow(title: "Show icon in menu bar") {
                    SnapToggle(isOn: $settings.showInMenuBar, accent: settings.accent.color)
                }
                RowDivider()
                SettingsRow(title: "Play capture sound") {
                    SnapToggle(isOn: $settings.captureSound, accent: settings.accent.color)
                }
            }
        }
    }
}

/// APPEARANCE card — theme segmented control + accent swatches.
struct AppearanceSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionEyebrow(text: "Appearance")
            SettingsCard {
                SettingsRow(title: "Theme") {
                    SegmentedControl(options: ThemeMode.allCases,
                                     selection: $settings.theme) { $0.title }
                }
                RowDivider()
                SettingsRow(title: "Annotation accent") {
                    HStack(spacing: 10) {
                        ForEach(AccentPalette.allCases) { accent in
                            let selected = settings.accent == accent
                            Circle()
                                .fill(accent.color)
                                .frame(width: selected ? 27 : 22, height: selected ? 27 : 22)
                                .overlay(
                                    Circle().stroke(accent.color, lineWidth: 1.5).padding(-3)
                                        .overlay(Circle().stroke(Theme.surface, lineWidth: 2).padding(-1.5))
                                        .opacity(selected ? 1 : 0)
                                )
                                .contentShape(Circle())
                                .onTapGesture { settings.accent = accent }
                        }
                    }
                }
            }
        }
    }
}
