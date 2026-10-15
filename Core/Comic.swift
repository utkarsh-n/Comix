import Foundation

struct ComicPage: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var filename: String
    var sourceName: String
    var width: Int
    var height: Int
    var caption = ""
}

struct Comic: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var title = "Untitled comic"
    var author = ""
    var series = ""
    var volume = ""
    var synopsis = ""
    var language = "en"
    var direction: ReadingDirection = .leftToRight
    var pages: [ComicPage] = []
    var modified = Date()

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled comic" : trimmed
    }
}

enum ReadingDirection: String, Codable, CaseIterable, Sendable {
    case leftToRight = "ltr", rightToLeft = "rtl"
    var label: String { self == .leftToRight ? "Left to right" : "Right to left" }
}

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case epub = "EPUB", pdf = "PDF"
    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
    var detail: String {
        self == .epub ? "A comic book with a cover, metadata, and page navigation. Best for Apple Books." : "One image per page, at its original proportions. Opens in almost any reader."
    }
}

enum ExportQuality: String, CaseIterable, Identifiable, Sendable {
    case compact = "Compact", balanced = "Balanced", original = "Original"
    var id: String { rawValue }
    var maxPixels: Int? {
        switch self { case .compact: 1600; case .balanced: 2560; case .original: nil }
    }
    var compression: Double { self == .compact ? 0.78 : 0.92 }
    var detail: String {
        switch self {
        case .compact: "Smaller files · up to 1,600 px"
        case .balanced: "Sharp pages · up to 2,560 px"
        case .original: "Full imported resolution · largest files"
        }
    }
}

enum ComixError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}
