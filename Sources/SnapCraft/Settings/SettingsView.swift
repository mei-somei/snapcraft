import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, shortcuts, saving, appearance, advanced, about
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .general:    return "slider.horizontal.3"
        case .shortcuts:  return "keyboard"
        case .saving:     return "folder"
        case .appearance: return "paintpalette"
        case .advanced:   return "gearshape.2"
        case .about:      return "info.circle"
        }
    }
}

/// The preferences window: top bar + sidebar + scrolling content column.
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var section: SettingsSection = .general

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(Theme.border)
            HStack(spacing: 0) {
                sidebar
                Divider().overlay(Theme.border)
                content
            }
        }
        .background(Theme.surface)
        .preferredColorScheme(settings.theme.colorScheme)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                NSApp.keyWindow?.performClose(nil)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.left").font(.system(size: 14))
                    Text("Editor").font(Theme.font(13.5, .semibold))
                }
                .foregroundStyle(Theme.text)
                .padding(.leading, 9).padding(.trailing, 12).frame(height: 36)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Text("snapcraft").font(Theme.font(16, .heavy)).tracking(-0.32)
                .foregroundStyle(settings.accent.color)
            Text("Settings").font(Theme.font(13.5, .medium)).foregroundStyle(Theme.textMuted)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { item in
                let active = section == item
                HStack(spacing: 11) {
                    Image(systemName: item.symbol).font(.system(size: 15))
                    Text(item.title).font(Theme.font(14, active ? .semibold : .regular))
                }
                .foregroundStyle(active ? settings.accent.color : Color(hex: 0x46423b))
                .padding(.horizontal, 11).padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(active ? settings.accent.tint : .clear))
                .contentShape(Rectangle())
                .onTapGesture { section = item }
            }
            Spacer()
            Text("SnapCraft 2.4.0").font(Theme.font(11.5)).foregroundStyle(Theme.textFaint)
                .padding(.horizontal, 11).padding(.vertical, 9)
        }
        .padding(.horizontal, 12).padding(.vertical, 14)
        .frame(width: 212)
        .background(Theme.sidebarBg)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(section.title)
                    .font(Theme.font(22, .bold)).tracking(-0.44)
                    .padding(.bottom, 4)
                Text(subtitle)
                    .font(Theme.font(13.5)).foregroundStyle(Theme.textMuted)
                    .padding(.bottom, 22)

                sections
            }
            .frame(maxWidth: 660, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30).padding(.vertical, 26)
        }
        .background(Theme.surface)
    }

    private var subtitle: String {
        switch section {
        case .general:    return "Capture shortcuts, where files go, and how SnapCraft behaves."
        case .shortcuts:  return "Customize the global keyboard shortcuts for capture."
        case .saving:     return "Choose where captures are saved and in what format."
        case .appearance: return "Theme and annotation accent."
        case .advanced:   return "Power-user options."
        case .about:      return "About SnapCraft."
        }
    }

    @ViewBuilder
    private var sections: some View {
        switch section {
        case .general:
            ShortcutsSection().padding(.bottom, 24)
            SavingSection().padding(.bottom, 24)
            BehaviorSection().padding(.bottom, 24)
            AppearanceSection()
        case .shortcuts:  ShortcutsSection()
        case .saving:     SavingSection().padding(.bottom, 24); BehaviorSection()
        case .appearance: AppearanceSection()
        case .advanced:   BehaviorSection()
        case .about:      AboutSection()
        }
    }
}

private struct AboutSection: View {
    var body: some View {
        SettingsCard {
            SettingsRow(title: "Version") { Text("2.4.0").font(Theme.font(13)).foregroundStyle(Theme.textSecondary) }
            RowDivider()
            SettingsRow(title: "Capture engine") { Text("ScreenCaptureKit").font(Theme.font(13)).foregroundStyle(Theme.textSecondary) }
            RowDivider()
            SettingsRow(title: "Text extraction") { Text("Vision OCR").font(Theme.font(13)).foregroundStyle(Theme.textSecondary) }
        }
    }
}
