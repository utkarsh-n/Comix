import Foundation
import CoreGraphics

actor ComicExporter {
    typealias Progress = @Sendable (Double) async -> Void

    func export(_ comic: Comic, folder: URL, format: ExportFormat, quality: ExportQuality,
                destination: URL? = nil, progress: Progress = { _ in }) async throws -> URL {
        guard !comic.pages.isEmpty else { throw ComixError.message("Add at least one page before exporting.") }
        guard !comic.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ComixError.message("Give your comic a title before exporting.")
        }
        let outputFolder = destination ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        // Each export is a revision. A share sheet can keep using an earlier file safely.
        let revision = outputFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: revision, withIntermediateDirectories: true)
        let output = revision.appendingPathComponent(Self.safeFilename(comic.displayTitle)).appendingPathExtension(format.fileExtension)
        do {
            switch format {
            case .pdf: try await pdf(comic, folder: folder, quality: quality, output: output, progress: progress)
            case .epub: try await epub(comic, folder: folder, quality: quality, output: output, progress: progress)
            }
            try Task.checkCancellation()
            await progress(1)
            return output
        } catch {
            try? FileManager.default.removeItem(at: revision)
            throw error
        }
    }

    private func pdf(_ comic: Comic, folder: URL, quality: ExportQuality, output: URL, progress: Progress) async throws {
        guard let consumer = CGDataConsumer(url: output as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: nil, [
                kCGPDFContextTitle: comic.displayTitle,
                kCGPDFContextAuthor: comic.author,
                kCGPDFContextSubject: comic.synopsis,
                kCGPDFContextKeywords: [comic.series].filter { !$0.isEmpty },
                kCGPDFContextCreator: "Comix"
              ] as CFDictionary) else { throw ComixError.message("The PDF could not be created.") }
        defer { context.closePDF() }
        for (index, page) in comic.pages.enumerated() {
            try Task.checkCancellation()
            try autoreleasepool {
                let image = try ImagePipeline.image(at: folder.appendingPathComponent(page.filename), maxPixels: quality.maxPixels)
                var bounds = CGRect(x: 0, y: 0, width: Double(page.width) / 2, height: Double(page.height) / 2)
                let mediaBox = Data(bytes: &bounds, count: MemoryLayout<CGRect>.size)
                context.beginPDFPage([kCGPDFContextMediaBox: mediaBox] as CFDictionary)
                context.setFillColor(CGColor(gray: 1, alpha: 1))
                context.fill(bounds)
                context.interpolationQuality = .high
                context.draw(image, in: bounds)
                context.endPDFPage()
            }
            await progress(Double(index + 1) / Double(comic.pages.count))
        }
    }

    private func epub(_ comic: Comic, folder: URL, quality: ExportQuality, output: URL, progress: Progress) async throws {
        let archive = try StoredZIP(url: output)
        try archive.add("mimetype", text: "application/epub+zip")
        try archive.add("META-INF/container.xml", text: """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>
        """)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        var manifest = ["<item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/>"]
        var spine: [String] = []
        var links: [String] = []
        let canvasWidth = 1000
        let canvasHeight = max(1, Int((Double(comic.pages[0].height) / Double(comic.pages[0].width) * 1000).rounded()))
        for (index, page) in comic.pages.enumerated() {
            try Task.checkCancellation()
            let number = index + 1
            let stem = String(format: "page-%04d", number)
            let source = folder.appendingPathComponent(page.filename)
            let prepared: (URL, String) = try autoreleasepool {
                // Apple Books specifies a maximum of 5.6 million pixels per image.
                let appleLimit = Int(floor(sqrt(5_600_000 / (Double(page.width) * Double(page.height))) * Double(max(page.width, page.height))))
                let maxPixels = min(quality.maxPixels ?? max(page.width, page.height), appleLimit)
                if quality == .original && maxPixels >= max(page.width, page.height) {
                    return (source, source.pathExtension.lowercased())
                }
                let target = temporary.appendingPathComponent("\(stem).jpg")
                try ImagePipeline.write(ImagePipeline.image(at: source, maxPixels: maxPixels), to: target,
                                        png: false, quality: quality == .original ? 1 : quality.compression)
                return (target, "jpg")
            }
            let imageName = "images/\(stem).\(prepared.1)"
            try archive.add("EPUB/\(imageName)", file: prepared.0)
            if prepared.0 != source { try FileManager.default.removeItem(at: prepared.0) }
            let mediaType = prepared.1 == "png" ? "image/png" : "image/jpeg"
            let cover = index == 0 ? " properties=\"cover-image\"" : ""
            manifest.append("<item id=\"image-\(number)\" href=\"\(imageName)\" media-type=\"\(mediaType)\"\(cover)/>")
            manifest.append("<item id=\"page-\(number)\" href=\"\(stem).xhtml\" media-type=\"application/xhtml+xml\"/>")
            spine.append("<itemref idref=\"page-\(number)\"/>")
            links.append("<li><a href=\"\(stem).xhtml\">\(index == 0 ? "Cover" : "Page \(number)")</a></li>")
            let alt = page.caption.isEmpty ? "\(comic.displayTitle), page \(number)" : page.caption
            try archive.add("EPUB/\(stem).xhtml", text: """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="\(Self.xml(comic.language))" lang="\(Self.xml(comic.language))">
            <head><title>\(Self.xml(comic.displayTitle)) — Page \(number)</title><meta name="viewport" content="width=\(canvasWidth), height=\(canvasHeight)"/>
            <style>html,body{margin:0;padding:0;width:\(canvasWidth)px;height:\(canvasHeight)px;background:white;}img{display:block;width:100%;height:100%;object-fit:contain;}</style></head>
            <body\(index == 0 ? " epub:type=\"cover\"" : "")><img src="\(imageName)" alt="\(Self.xml(alt))"/></body></html>
            """)
            await progress(Double(number) / Double(comic.pages.count + 1))
        }
        try archive.add("EPUB/nav.xhtml", text: """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="\(Self.xml(comic.language))" lang="\(Self.xml(comic.language))">
        <head><title>\(Self.xml(comic.displayTitle)) — Contents</title></head><body>
        <nav epub:type="toc" id="toc"><h1>Contents</h1><ol>\(links.joined())</ol></nav>
        <nav epub:type="page-list"><h2>Pages</h2><ol>\(links.joined())</ol></nav>
        <nav epub:type="landmarks" hidden="hidden"><h2>Landmarks</h2><ol><li><a epub:type="cover" href="page-0001.xhtml">Cover</a></li></ol></nav>
        </body></html>
        """)
        let date = ISO8601DateFormatter().string(from: Date())
        var metadata = """
        <dc:identifier id="book-id">urn:uuid:\(comic.id.uuidString)</dc:identifier>
        <dc:title>\(Self.xml(comic.displayTitle))</dc:title><dc:language>\(Self.xml(comic.language))</dc:language>
        <meta property="dcterms:modified">\(date)</meta>
        <meta property="rendition:layout">pre-paginated</meta><meta property="rendition:spread">none</meta>
        <meta property="rendition:orientation">auto</meta>
        """
        if !comic.author.isEmpty { metadata += "<dc:creator>\(Self.xml(comic.author))</dc:creator>" }
        if !comic.synopsis.isEmpty { metadata += "<dc:description>\(Self.xml(comic.synopsis))</dc:description>" }
        if !comic.series.isEmpty {
            metadata += "<meta property=\"belongs-to-collection\" id=\"series\">\(Self.xml(comic.series))</meta><meta refines=\"#series\" property=\"collection-type\">series</meta>"
            if let volume = Double(comic.volume), volume > 0, volume.isFinite {
                metadata += "<meta refines=\"#series\" property=\"group-position\">\(volume)</meta>"
            }
        }
        try archive.add("EPUB/package.opf", text: """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id" prefix="rendition: http://www.idpf.org/vocab/rendition/#">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\(metadata)</metadata>
        <manifest>\(manifest.joined())</manifest><spine page-progression-direction="\(comic.direction.rawValue)">\(spine.joined())</spine></package>
        """)
        try archive.finish()
    }

    nonisolated static func xml(_ string: String) -> String {
        let clean = String(string.unicodeScalars.filter { scalar in
            scalar.value == 9 || scalar.value == 10 || scalar.value == 13 ||
            (scalar.value >= 32 && scalar.value <= 0xD7FF) ||
            (scalar.value >= 0xE000 && scalar.value <= 0xFFFD) ||
            (scalar.value >= 0x10000 && scalar.value <= 0x10FFFF)
        })
        return clean.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    nonisolated static func safeFilename(_ title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?").union(.controlCharacters)
        let clean = title.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return clean.isEmpty ? "Comic" : String(clean.prefix(100))
    }
}
