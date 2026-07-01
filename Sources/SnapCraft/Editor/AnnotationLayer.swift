import SwiftUI

/// Renders a list of annotations over the captured image. Geometry is in image
/// point space; the layer scales to whatever frame it is given (live canvas or
/// full-resolution export), so the editor and the exporter share one renderer.
struct AnnotationLayer: View {
    let image: NSImage
    let imageSize: CGSize
    let annotations: [Annotation]

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / max(imageSize.width, 1)

            ZStack(alignment: .topLeading) {
                // Blur / redaction: a blurred copy of the image clipped to each rect.
                ForEach(annotations.filter { $0.kind == .blur }) { a in
                    let r = a.rect.scaled(scale)
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 9 * scale, opaque: true)
                        .overlay(Color(hex: 0x14121e, alpha: 0.30))
                        .mask(alignment: .topLeading) {
                            Rectangle().frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
                        }
                        .overlay(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                .frame(width: r.width, height: r.height)
                                .offset(x: r.minX, y: r.minY)
                        }
                        .allowsHitTesting(false)
                }

                // Vector marks: arrow / line / shape / pen / marker.
                Canvas { ctx, _ in
                    for a in annotations { drawVector(a, in: &ctx, scale: scale) }
                }

                // Text + numbered-step badges as crisp SwiftUI views.
                ForEach(annotations.filter { $0.kind == .text || $0.kind == .step }) { a in
                    overlay(for: a, scale: scale)
                }
            }
        }
    }

    // MARK: Vector kinds

    private func drawVector(_ a: Annotation, in ctx: inout GraphicsContext, scale: CGFloat) {
        let s = a.start.scaled(scale)
        let e = a.end.scaled(scale)
        let lineW = a.strokeWidth * scale
        let style = StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)

        switch a.kind {
        case .line:
            var p = Path(); p.move(to: s); p.addLine(to: e)
            ctx.stroke(p, with: .color(a.color), style: style)

        case .arrow:
            var p = Path(); p.move(to: s); p.addLine(to: e)
            ctx.stroke(p, with: .color(a.color), style: style)
            ctx.stroke(arrowHead(from: s, to: e, size: max(12, lineW * 3.2)),
                       with: .color(a.color), style: style)

        case .shape:
            let r = a.rect.scaled(scale)
            ctx.stroke(Path(roundedRect: r, cornerRadius: 2 * scale),
                       with: .color(a.color), style: style)

        case .pen:
            guard a.points.count > 1 else { return }
            var p = Path()
            p.move(to: a.points[0].scaled(scale))
            for pt in a.points.dropFirst() { p.addLine(to: pt.scaled(scale)) }
            ctx.stroke(p, with: .color(a.color), style: style)

        case .marker:
            let r = a.rect.scaled(scale)
            var copy = ctx
            copy.blendMode = .multiply
            copy.fill(Path(CGRect(x: r.minX, y: r.minY, width: r.width, height: max(r.height, 10 * scale))),
                      with: .color(Theme.swatchYellow.opacity(0.8)))

        default:
            break
        }
    }

    private func arrowHead(from: CGPoint, to: CGPoint, size: CGFloat) -> Path {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let a1 = angle + .pi * 0.82
        let a2 = angle - .pi * 0.82
        var p = Path()
        p.move(to: CGPoint(x: to.x + cos(a1) * size, y: to.y + sin(a1) * size))
        p.addLine(to: to)
        p.addLine(to: CGPoint(x: to.x + cos(a2) * size, y: to.y + sin(a2) * size))
        return p
    }

    // MARK: Text + step overlays

    @ViewBuilder
    private func overlay(for a: Annotation, scale: CGFloat) -> some View {
        let p = a.start.scaled(scale)
        switch a.kind {
        case .text:
            // Empty text renders nothing (the inline editor shows its own
            // placeholder); avoids stray "Text" labels from abandoned clicks.
            if !a.text.isEmpty {
                Text(a.text)
                    .font(.system(size: max(14, a.strokeWidth * 2.4) * scale, weight: .semibold))
                    .foregroundStyle(a.color)
                    .fixedSize()
                    .offset(x: p.x, y: p.y)
            }
        case .step:
            let d: CGFloat = 26 * scale
            Text("\(a.stepNumber)")
                .font(.system(size: 14 * scale, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: d, height: d)
                .background(Circle().fill(a.color))
                .shadow(color: .black.opacity(0.25), radius: 3 * scale, y: 2 * scale)
                .offset(x: p.x - d / 2, y: p.y - d / 2)
        default:
            EmptyView()
        }
    }
}

extension CGPoint {
    func scaled(_ s: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
}
extension CGRect {
    func scaled(_ s: CGFloat) -> CGRect {
        CGRect(x: minX * s, y: minY * s, width: width * s, height: height * s)
    }
}
