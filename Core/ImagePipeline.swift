import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

enum ImagePipeline {
    static func source(_ url: URL) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ComixError.message("This file could not be opened as an image: \(url.lastPathComponent)")
        }
        return source
    }

    static func dimensions(_ source: CGImageSource) throws -> (Int, Int, Int) {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int, width > 0, height > 0 else {
            throw ComixError.message("This image has no readable dimensions.")
        }
        return (width, height, props[kCGImagePropertyOrientation] as? Int ?? 1)
    }

    static func image(at url: URL, maxPixels: Int? = nil) throws -> CGImage {
        let source = try source(url)
        let (width, height, _) = try dimensions(source)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixels ?? max(width, height), max(width, height)),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ComixError.message("This image could not be decoded: \(url.lastPathComponent)")
        }
        return image
    }

    static func write(_ image: CGImage, to url: URL, png: Bool, quality: Double = 1) throws {
        var output = image
        if !png {
            // JPEG cannot store transparency. Flatten on white, never black.
            guard let context = CGContext(data: nil, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                throw ComixError.message("There is not enough memory to prepare this page.")
            }
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let flattened = context.makeImage() else { throw ComixError.message("Could not prepare this page.") }
            output = flattened
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL,
            (png ? UTType.png.identifier : UTType.jpeg.identifier) as CFString, 1, nil) else {
            throw ComixError.message("Could not write this page. Check your available storage.")
        }
        CGImageDestinationAddImage(destination, output, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ComixError.message("The image could not be saved.") }
    }

    static func importImage(from url: URL, into folder: URL, sourceName: String? = nil) throws -> ComicPage {
        let source = try source(url)
        let (width, height, orientation) = try dimensions(source)
        let type = CGImageSourceGetType(source) as String? ?? ""
        let png = type == UTType.png.identifier
        let id = UUID()
        let filename = "\(id.uuidString).\(png ? "png" : "jpg")"
        let target = folder.appendingPathComponent(filename)
        if orientation == 1 && (png || type == UTType.jpeg.identifier) {
            try FileManager.default.copyItem(at: url, to: target)
        } else {
            try write(image(at: url), to: target, png: png)
        }
        let rotated = [5, 6, 7, 8].contains(orientation)
        return ComicPage(id: id, filename: filename, sourceName: sourceName ?? url.lastPathComponent,
                         width: rotated ? height : width, height: rotated ? width : height)
    }
}

actor ImageImporter {
    func importFile(_ url: URL, into folder: URL) throws -> ComicPage {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return try autoreleasepool { try ImagePipeline.importImage(from: url, into: folder) }
    }

    func importData(_ data: Data, into folder: URL, name: String) throws -> ComicPage {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary)
        return try autoreleasepool { try ImagePipeline.importImage(from: temporary, into: folder, sourceName: name) }
    }
}
