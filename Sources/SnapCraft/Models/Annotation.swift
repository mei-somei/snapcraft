import SwiftUI

/// A single drawn mark. All geometry is stored in *image coordinate space*
/// (points of the captured image, origin top-left) so annotations stay locked
/// to the picture under zoom/pan and composite cleanly on export.
struct Annotation: Identifiable {
    enum Kind {
        case arrow
        case line
        case shape      // rectangle outline
        case pen        // freehand path
        case marker     // highlighter rectangle (multiply blend)
        case text
        case step       // numbered badge
        case blur       // redaction rectangle
    }

    let id = UUID()
    var kind: Kind
    var color: Color
    var strokeWidth: CGFloat

    /// Bounding interaction points. For most kinds `start`→`end` defines the
    /// shape; `pen` uses `points`; `text`/`step` anchor at `start`.
    var start: CGPoint = .zero
    var end: CGPoint = .zero
    var points: [CGPoint] = []

    // Tool-specific payloads.
    var text: String = ""
    var stepNumber: Int = 1

    var rect: CGRect {
        CGRect(x: min(start.x, end.x),
               y: min(start.y, end.y),
               width: abs(end.x - start.x),
               height: abs(end.y - start.y))
    }
}

/// Stroke thickness presets surfaced as the three dots in the contextual bar.
enum StrokeWidth: CGFloat, CaseIterable, Identifiable {
    case thin   = 3
    case medium = 6
    case thick  = 10

    var id: CGFloat { rawValue }

    /// Display diameter of the selector dot (design: 6 / 10 / 15 px).
    var dotDiameter: CGFloat {
        switch self {
        case .thin:   return 6
        case .medium: return 10
        case .thick:  return 15
        }
    }
}
