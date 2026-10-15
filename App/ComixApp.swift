import SwiftUI

@main
struct ComixApp: App {
    @State private var library: ComicLibrary

    init() {
        // UI tests use a disposable library without touching installed drafts.
        let isolated = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let root = isolated ? FileManager.default.temporaryDirectory
            .appendingPathComponent("ComixUITests-\(UUID().uuidString)", isDirectory: true) : nil
        _library = State(initialValue: ComicLibrary(root: root))
    }

    var body: some Scene {
        WindowGroup {
            LibraryView(library: library)
                .tint(Palette.accent)
                .alert("Couldn't complete that", isPresented: Binding(
                    get: { library.error != nil }, set: { if !$0 { library.error = nil } }
                )) { Button("OK", role: .cancel) { library.error = nil } }
                message: { Text(library.error ?? "") }
        }
    }
}
