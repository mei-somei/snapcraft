import SwiftUI

// MARK: - Card + Row scaffolding

/// A bordered settings card; rows are separated by indented hairlines.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.border, lineWidth: 1))
    }
}

/// One 13/16-padded row with a leading label and trailing accessory.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.font(14)).foregroundStyle(Color(hex: 0x26241f))
                if let subtitle {
                    Text(subtitle).font(Theme.font(12)).foregroundStyle(Color(hex: 0x9a958a))
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// Indented hairline divider between rows.
struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Theme.rowHairline).frame(height: 1).padding(.leading, 16)
    }
}

/// Uppercase eyebrow label above each card.
struct SectionEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.font(12, .bold))
            .tracking(0.48)
            .foregroundStyle(Theme.textFaint)
            .padding(.horizontal, 2)
            .padding(.bottom, 9)
    }
}

// MARK: - Controls

/// 42×25 toggle: accent fill when on, neutral track when off.
struct SnapToggle: View {
    @Binding var isOn: Bool
    let accent: Color

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: Theme.Radius.toggle)
                    .fill(isOn ? accent : Theme.toggleOff)
                    .frame(width: 42, height: 25)
                Circle()
                    .fill(.white)
                    .frame(width: 21, height: 21)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Light / Dark / Auto segmented control.
struct SegmentedControl<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { opt in
                let selected = opt == selection
                Text(label(opt))
                    .font(Theme.font(13, selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.text : Theme.textSecondary)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selected ? Theme.surface : .clear)
                            .shadow(color: selected ? .black.opacity(0.12) : .clear, radius: 1, y: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selection = opt }
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.rowHairline))
    }
}

/// A single keycap chip (e.g. ⌘ or 4).
struct KeyCap: View {
    let label: String
    var body: some View {
        Text(label)
            .font(Theme.font(13, .semibold))
            .foregroundStyle(Color(hex: 0x46423b))
            .frame(minWidth: 27, minHeight: 27)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.chip).fill(Theme.chipFill))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.chipBorder, lineWidth: 1))
    }
}

/// A bordered chip button (e.g. "Choose…", "PNG ⌃").
struct ChipButton: View {
    let title: String
    var trailingSymbol: String? = nil
    var leadingSymbol: String? = nil
    var leadingTint: Color = Theme.text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let leadingSymbol {
                    Image(systemName: leadingSymbol).font(.system(size: 12)).foregroundStyle(leadingTint)
                }
                Text(title).font(Theme.font(13, .semibold)).foregroundStyle(Theme.text)
                if let trailingSymbol {
                    Image(systemName: trailingSymbol).font(.system(size: 11)).foregroundStyle(Color(hex: 0x9a958a))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.borderStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Read-only path chip (folder icon + path).
struct PathChip: View {
    let path: String
    let accent: Color
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "folder").font(.system(size: 12)).foregroundStyle(accent)
            Text(path).font(Theme.font(13)).foregroundStyle(Theme.textSecondary).lineLimit(1)
        }
        .padding(.horizontal, 11).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.chipFill))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.chipBorder, lineWidth: 1))
    }
}
