import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Flattens a capture + its annotations to a single bitmap and routes it to the
/// clipboard, disk, or a pin window. Compositing reuses `AnnotationLayer` so the
/// exported pixels match the editor exactly.
@MainActor
enum Exporter {

    /// Render the capture with annotations baked in, at full native resolution.
    static func composite(capture: CapturedImage, annotations: [Annotation]) -> NSImage {
        let size = capture.size
        let content = ZStack(alignment: .topLeading) {
            Image(nsImage: capture.image)
                .resizable()
                .frame(width: size.width, height: size.height)
            AnnotationLayer(image: capture.image, imageSize: size, annotations: annotations)
                .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = pixelScale(of: capture.image)
        return renderer.nsImage ?? capture.image
    }

    // MARK: Destinations

    @discardableResult
    static func copyToClipboard(capture: CapturedImage, annotations: [Annotation]) -> Bool {
        let image = composite(capture: capture, annotations: annotations)
        let pb = NSPasteboard.general
        pb.clearContents()
        guard let png = pngData(image) else { return pb.writeObjects([image]) }
        pb.setData(png, forType: .png)
        pb.setData(image.tiffRepresentation, forType: .tiff)
        return true
    }

    /// Save to the configured location/format. Returns the written URL.
    @discardableResult
    static func saveToFile(capture: CapturedImage, annotations: [Annotation],
                           settings: AppSettings) -> URL? {
        let image = composite(capture: capture, annotations: annotations)
        let dir = URL(fileURLWithPath: settings.saveLocation, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = capture.caption.replacingOccurrences(of: ".png", with: "")
        let url = dir.appendingPathComponent(base).appendingPathExtension(settings.fileFormat.fileExtension)
        guard let data = encode(image, as: settings.fileFormat) else { return nil }
        do { try data.write(to: url); return url } catch { return nil }
    }

    /// Present a save panel for an explicit "Save As…".
    static func saveWithPanel(capture: CapturedImage, annotations: [Annotation],
                              settings: AppSettings) {
        let image = composite(capture: capture, annotations: annotations)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = capture.caption
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [settings.fileFormat.utType]
        panel.directoryURL = URL(fileURLWithPath: settings.saveLocation)
        if panel.runModal() == .OK, let url = panel.url,
           let data = encode(image, as: settings.fileFormat) {
            try? data.write(to: url)
        }
    }

    // MARK: Encoding helpers

    static func pngData(_ image: NSImage) -> Data? { encode(image, as: .png) }

    static func encode(_ image: NSImage, as format: FileFormat) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        switch format {
        case .png:  return rep.representation(using: .png, properties: [:])
        case .jpeg: return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
        case .tiff: return tiff
        }
    }

    private static func pixelScale(of image: NSImage) -> CGFloat {
        guard let rep = image.representations.first as? NSBitmapImageRep, image.size.width > 0
        else { return 2 }
        return CGFloat(rep.pixelsWide) / image.size.width
    }
}

private extension FileFormat {
    var utType: UTType {
        switch self {
        case .png:  return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        }
    }
}
