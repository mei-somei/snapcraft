import SwiftUI

/// Full-bleed dot grid matching the design's radial-gradient backdrop.
struct DotGridView: View {
    var body: some View {
        Canvas { ctx, size in
            let step = Theme.gridSpacing
            let r = Theme.gridDotRadius
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(Theme.gridDot))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}
