import Foundation

/// Editor tools. Order/grouping in the vertical strip is defined by
/// `ToolStrip.groups`; SF Symbol names approximate the Lucide set in the design.
enum Tool: String, CaseIterable, Identifiable {
    case select     // mouse-pointer-2
    case crop       // crop
    case shape      // square
    case arrow      // arrow-up-right  (default active)
    case doubleArrow // move-horizontal (arrowheads on both ends)
    case line       // minus
    case tooltip    // message-square (text callout bubble)
    case pen        // pencil
    case marker     // highlighter
    case text       // type
    case step       // list-ordered
    case blur       // eye-off (redact)
    case ocr        // scan-text (extract text)

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: return "Select"
        case .crop:   return "Crop"
        case .shape:  return "Shape"
        case .arrow:  return "Arrow"
        case .doubleArrow: return "Double arrow"
        case .line:   return "Line"
        case .tooltip: return "Tooltip"
        case .pen:    return "Pen"
        case .marker: return "Highlighter"
        case .text:   return "Text"
        case .step:   return "Numbered step"
        case .blur:   return "Blur / redact"
        case .ocr:    return "Extract text (OCR)"
        }
    }

    var sfSymbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .crop:   return "crop"
        case .shape:  return "square"
        case .arrow:  return "arrow.up.right"
        case .doubleArrow: return "arrow.left.and.right"
        case .line:   return "minus"
        case .tooltip: return "bubble.left"
        case .pen:    return "pencil"
        case .marker: return "highlighter"
        case .text:   return "textformat"
        case .step:   return "list.number"
        case .blur:   return "eye.slash"
        case .ocr:    return "text.viewfinder"
        }
    }

    /// Single-key shortcut (no modifier) that activates the tool in the editor.
    var shortcut: Character {
        switch self {
        case .select: return "v"
        case .crop:   return "c"
        case .shape:  return "r"   // rectangle
        case .arrow:  return "a"
        case .doubleArrow: return "d"
        case .line:   return "l"
        case .tooltip: return "u"
        case .pen:    return "p"
        case .marker: return "h"   // highlighter
        case .text:   return "t"
        case .step:   return "n"   // numbered
        case .blur:   return "b"
        case .ocr:    return "o"
        }
    }

    /// Uppercased keycap label for tooltips / badges.
    var shortcutLabel: String { String(shortcut).uppercased() }

    /// Whether selecting this tool produces a drawn annotation on drag.
    var isDrawing: Bool {
        switch self {
        case .select, .crop, .ocr: return false
        default: return true
        }
    }
}
