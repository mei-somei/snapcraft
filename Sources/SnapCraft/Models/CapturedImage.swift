import AppKit

/// A screenshot handed to the editor: the pixels plus a display caption.
struct CapturedImage: Identifiable {
    let id = UUID()
    let image: NSImage
    var caption: String

    /// The on-screen rect this capture came from, in global AppKit coordinates
    /// (bottom-left origin). When set, the editor opens as an in-place layer
    /// sized and positioned exactly over the captured region. `nil` for window
    /// / fullscreen captures, which open the standard centered editor.
    var screenFrame: CGRect?

    /// Logical point size of the image (annotation coordinate space).
    var size: CGSize { image.size }

    /// Build the default caption / filename from the source app and an optional
    /// detail (window title, document, folder, or URL). Falls back to "Capture".
    /// e.g. "Safari — Pricing 2026-06-28 at 22.10.png".
    static func makeCaption(app: String? = nil,
                            detail: String? = nil,
                            date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm"
        let stamp = f.string(from: date)

        var name = sanitize(app) ?? "Capture"
        if let detail = sanitize(detail), !detail.isEmpty {
            name += " — \(detail)"
        }
        return "\(name) \(stamp).png"
    }

    /// Make a string safe for a filename: strip path separators / control
    /// characters, collapse whitespace, and cap the length.
    private static func sanitize(_ s: String?, maxLength: Int = 60) -> String? {
        guard let s else { return nil }
        let cleaned = s
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .components(separatedBy: .controlCharacters).joined()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        return cleaned.count > maxLength ? String(cleaned.prefix(maxLength)).trimmingCharacters(in: .whitespaces) + "…" : cleaned
    }
}
