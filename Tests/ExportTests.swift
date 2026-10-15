import XCTest
import PDFKit
import ImageIO
import UniformTypeIdentifiers
@testable import Comix

final class ExportTests: XCTestCase {
    private var temporary: URL!
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: temporary) }

    private func fixture() async throws -> Comic {
        var comic = Comic()
        comic.title = "Moon & Stars <Vol. 1>"
        comic.author = "A. O'Neil"
        comic.synopsis = "A \"small\" story & a big sky.\u{0001}"
        comic.series = "Night & Day"
        comic.volume = "2"
        comic.direction = .rightToLeft
        comic.pages = try await SampleComic.make(in: temporary)
        comic.pages[1].caption = "Travel over the river & hills."
        return comic
    }

    func testEPUBContainerResourcesOrderAndMetadata() async throws {
        let comic = try await fixture()
        let output = try await ComicExporter().export(comic, folder: temporary, format: .epub, quality: .balanced, destination: temporary.appendingPathComponent("output"))
        let archive = try readZIP(output)
        XCTAssertEqual(archive.names.first, "mimetype")
        XCTAssertEqual(String(data: try XCTUnwrap(archive.files["mimetype"]), encoding: .utf8), "application/epub+zip")
        // Parse every XML/XHTML document; special characters and illegal controls
        // must not produce malformed metadata or page descriptions.
        for (name, data) in archive.files where name.hasSuffix("xml") || name.hasSuffix("opf") || name.hasSuffix("xhtml") {
            let parser = XMLParser(data: data)
            XCTAssertTrue(parser.parse(), "\(name): \(String(describing: parser.parserError))")
        }
        let package = try String(data: XCTUnwrap(archive.files["EPUB/package.opf"]), encoding: .utf8).unwrap()
        XCTAssertTrue(package.contains("Moon &amp; Stars &lt;Vol. 1&gt;"))
        XCTAssertTrue(package.contains("page-progression-direction=\"rtl\""))
        XCTAssertTrue(package.contains("properties=\"cover-image\""))
        XCTAssertTrue(package.contains("pre-paginated"))
        XCTAssertTrue(package.contains("collection-type\">series"))
        let spine = package.components(separatedBy: "<spine")[1]
        XCTAssertLessThan(try spine.range(of: "page-1").unwrap().lowerBound, try spine.range(of: "page-2").unwrap().lowerBound)
        XCTAssertLessThan(try spine.range(of: "page-2").unwrap().lowerBound, try spine.range(of: "page-3").unwrap().lowerBound)
        XCTAssertEqual(archive.files.keys.filter { $0.hasPrefix("EPUB/images/") }.count, 3)
        let page = try String(data: XCTUnwrap(archive.files["EPUB/page-0002.xhtml"]), encoding: .utf8).unwrap()
        XCTAssertTrue(page.contains("river &amp; hills."))
        for number in 1...3 {
            XCTAssertNotNil(archive.files[String(format: "EPUB/images/page-%04d.jpg", number)])
            XCTAssertTrue(page.contains("width=1000, height=1422"))
        }
    }

    func testPDFContainsAllPagesInOrderWithProportionsAndMetadata() async throws {
        var comic = try await fixture()
        // Mixed aspect ratios must survive PDF export without a common crop.
        let wide = try image(width: 240, height: 120, color: .red, name: "wide.png")
        comic.pages[1] = try ImagePipeline.importImage(from: wide, into: temporary)
        let output = try await ComicExporter().export(comic, folder: temporary, format: .pdf, quality: .original, destination: temporary.appendingPathComponent("output"))
        let pdf = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(pdf.pageCount, 3)
        XCTAssertEqual(pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, comic.title)
        XCTAssertEqual(pdf.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String, comic.author)
        XCTAssertEqual(try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox).size, CGSize(width: 450, height: 640))
        XCTAssertEqual(try XCTUnwrap(pdf.page(at: 1)).bounds(for: .mediaBox).size, CGSize(width: 120, height: 60))
        XCTAssertEqual(try XCTUnwrap(pdf.page(at: 2)).bounds(for: .mediaBox).size, CGSize(width: 450, height: 640))
    }

    func testOriginalEPUBRespectsAppleImageLimit() async throws {
        let large = try image(width: 3000, height: 3000, color: .blue, name: "large.png")
        var comic = Comic(); comic.title = "Large page"
        comic.pages = [try ImagePipeline.importImage(from: large, into: temporary)]
        let output = try await ComicExporter().export(comic, folder: temporary, format: .epub, quality: .original, destination: temporary.appendingPathComponent("output"))
        let archive = try readZIP(output)
        let data = try XCTUnwrap(archive.files["EPUB/images/page-0001.jpg"])
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let (width, height, _) = try ImagePipeline.dimensions(source)
        XCTAssertLessThanOrEqual(width * height, 5_600_000)
        XCTAssertEqual(width, height)
        // Draft source remains full resolution.
        XCTAssertEqual(comic.pages[0].width, 3000)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.appendingPathComponent(comic.pages[0].filename).path))
    }

    func testEmptyOrMissingPagesDoNotLeavePartialExports() async throws {
        let outputFolder = temporary.appendingPathComponent("output")
        do {
            _ = try await ComicExporter().export(Comic(), folder: temporary, format: .epub, quality: .balanced, destination: outputFolder)
            XCTFail("Empty comic exported")
        } catch { XCTAssertFalse(FileManager.default.fileExists(atPath: outputFolder.path)) }
        var comic = Comic()
        comic.pages = [ComicPage(filename: "missing.png", sourceName: "Missing", width: 10, height: 20)]
        for format in ExportFormat.allCases {
            do {
                _ = try await ComicExporter().export(comic, folder: temporary, format: format, quality: .balanced, destination: outputFolder)
                XCTFail("Missing image exported")
            } catch { XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outputFolder.path).count, 0) }
        }
    }

    func testImportRotatesHEIFStyleOrientationAndPreservesPNG() throws {
        let png = try image(width: 80, height: 120, color: .green, name: "source.png")
        let copied = try ImagePipeline.importImage(from: png, into: temporary)
        XCTAssertEqual(try Data(contentsOf: png), try Data(contentsOf: temporary.appendingPathComponent(copied.filename)))
        let rotated = temporary.appendingPathComponent("rotated.jpg")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(rotated as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try ImagePipeline.image(at: png), [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let imported = try ImagePipeline.importImage(from: rotated, into: temporary)
        XCTAssertEqual(imported.width, 120); XCTAssertEqual(imported.height, 80)
        let normalized = try ImagePipeline.image(at: temporary.appendingPathComponent(imported.filename))
        XCTAssertEqual(normalized.width, 120); XCTAssertEqual(normalized.height, 80)
    }

    @MainActor func testDraftPersistenceAfterReorderAndDeletion() async throws {
        let root = temporary.appendingPathComponent("Drafts")
        let library = ComicLibrary(root: root)
        let comic = try library.create()
        let pages = try await SampleComic.make(in: library.folder(comic.id))
        for page in pages { library.append(page, to: comic.id) }
        library.update(comic.id) { $0.title = "Saved title"; $0.author = "Author"; $0.pages.swapAt(0, 2) }
        let reloaded = ComicLibrary(root: root)
        let saved = try XCTUnwrap(reloaded.comic(comic.id))
        XCTAssertEqual(saved.title, "Saved title"); XCTAssertEqual(saved.author, "Author")
        XCTAssertEqual(saved.pages.map(\.id), [pages[2].id, pages[1].id, pages[0].id])
        reloaded.deletePage(pages[1], from: comic.id)
        XCTAssertEqual(ComicLibrary(root: root).comic(comic.id)?.pages.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: reloaded.imageURL(pages[1], in: comic.id).path))
    }

    private func image(width: Int, height: Int, color: UIColor, name: String) throws -> URL {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let value = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            color.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let url = temporary.appendingPathComponent(name)
        try XCTUnwrap(value.pngData()).write(to: url)
        return url
    }

    /// Independent ZIP reader verifies local records, checksums, and archive
    /// finalization, rather than accepting a file just because its suffix is epub.
    private func readZIP(_ url: URL) throws -> (names: [String], files: [String: Data]) {
        let data = try Data(contentsOf: url)
        var offset = 0
        var names: [String] = []; var files: [String: Data] = [:]
        func u16(_ offset: Int) -> Int { Int(data[offset]) | Int(data[offset + 1]) << 8 }
        func u32(_ offset: Int) -> UInt32 { UInt32(u16(offset)) | UInt32(u16(offset + 2)) << 16 }
        while offset + 30 <= data.count && u32(offset) == 0x04034b50 {
            XCTAssertEqual(u16(offset + 8), 0)
            let size = Int(u32(offset + 18)); let nameLength = u16(offset + 26); let extraLength = u16(offset + 28)
            if names.isEmpty { XCTAssertEqual(extraLength, 0) }
            let start = offset + 30 + nameLength + extraLength
            guard start + size <= data.count else { throw ComixError.message("Truncated ZIP entry") }
            let name = try String(data: data.subdata(in: offset + 30..<offset + 30 + nameLength), encoding: .utf8).unwrap()
            let content = data.subdata(in: start..<start + size)
            XCTAssertEqual(StoredZIP.checksum(content), u32(offset + 14), "CRC: \(name)")
            names.append(name); files[name] = content; offset = start + size
        }
        XCTAssertEqual(u32(offset), 0x02014b50)
        let end = data.count - 22
        XCTAssertGreaterThanOrEqual(end, offset)
        XCTAssertEqual(u32(end), 0x06054b50)
        XCTAssertEqual(u16(end + 10), names.count)
        XCTAssertEqual(Int(u32(end + 16)), offset)
        return (names, files)
    }
}

private extension Optional {
    func unwrap(file: StaticString = #filePath, line: UInt = #line) throws -> Wrapped { try XCTUnwrap(self, file: file, line: line) }
}
