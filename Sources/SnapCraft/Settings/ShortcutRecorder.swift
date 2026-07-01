import SwiftUI
import AppKit

/// A keycap row that records a new global shortcut. Click to arm; the next key
/// press (with modifiers) becomes the binding. Esc cancels, ⌫ is ignored.
struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            HStack(spacing: 5) {
                if recording {
                    Text("Recording…")
                        .font(Theme.font(13, .semibold))
                        .foregroundStyle(AccentPalette.signalRed.color)
                        .frame(minWidth: 27, minHeight: 27)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.chip)
                            .stroke(AccentPalette.signalRed.color, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                } else {
                    ForEach(Array(combo.keyCaps.enumerated()), id: \.offset) { _, cap in
                        KeyCap(label: cap)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .help("Click to change shortcut")
        .onDisappear { teardown() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }           // Esc cancels
            guard let label = KeyCombo.label(forKeyCode: event.keyCode) else { return nil }
            let flags = event.modifierFlags
            combo = KeyCombo(
                command: flags.contains(.command),
                shift: flags.contains(.shift),
                option: flags.contains(.option),
                control: flags.contains(.control),
                keyCode: UInt32(event.keyCode),
                display: label)
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        teardown()
    }

    private func teardown() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }
}
