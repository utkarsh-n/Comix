import Foundation
import Observation

@MainActor @Observable
final class ComicLibrary {
    private(set) var comics: [Comic] = []
    var error: String?
    let root: URL

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Drafts", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            let directories = try FileManager.default.contentsOfDirectory(at: self.root, includingPropertiesForKeys: nil)
            for directory in directories {
                let file = directory.appendingPathComponent("comic.json")
                guard FileManager.default.fileExists(atPath: file.path) else { continue }
                do { comics.append(try JSONDecoder().decode(Comic.self, from: Data(contentsOf: file))) }
                catch { self.error = "A saved draft could not be opened. Its images are still in Files → Comix → Drafts." }
            }
            comics.sort { $0.modified > $1.modified }
        } catch { self.error = error.localizedDescription }
    }

    func comic(_ id: UUID) -> Comic? { comics.first { $0.id == id } }
    func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    func imageURL(_ page: ComicPage, in id: UUID) -> URL { folder(id).appendingPathComponent(page.filename) }

    @discardableResult func create() throws -> Comic {
        let comic = Comic()
        try FileManager.default.createDirectory(at: folder(comic.id), withIntermediateDirectories: true)
        try persist(comic)
        comics.insert(comic, at: 0)
        return comic
    }

    func update(_ id: UUID, _ mutate: (inout Comic) -> Void) {
        guard let index = comics.firstIndex(where: { $0.id == id }) else { return }
        var updated = comics[index]
        mutate(&updated)
        updated.modified = Date()
        do { try persist(updated); comics[index] = updated }
        catch { self.error = "Changes could not be saved: \(error.localizedDescription)" }
    }

    func append(_ page: ComicPage, to id: UUID) { update(id) { $0.pages.append(page) } }
    func deletePage(_ page: ComicPage, from id: UUID) {
        update(id) { $0.pages.removeAll { $0.id == page.id } }
        if comic(id)?.pages.contains(where: { $0.id == page.id }) == false {
            try? FileManager.default.removeItem(at: imageURL(page, in: id))
        }
    }
    func delete(_ id: UUID) throws {
        try FileManager.default.removeItem(at: folder(id))
        comics.removeAll { $0.id == id }
    }
    private func persist(_ comic: Comic) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(comic).write(to: folder(comic.id).appendingPathComponent("comic.json"), options: .atomic)
    }
}
