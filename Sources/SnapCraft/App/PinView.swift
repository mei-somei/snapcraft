import SwiftUI

/// A floating always-on-top capture. Drag to move (window is movable by
/// background); a close button appears on hover.
struct PinView: View {
    let image: NSImage
    let onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.5), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if hovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            .padding(8)
            .onHover { hovering = $0 }
    }
}
