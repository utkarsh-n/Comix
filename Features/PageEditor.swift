import SwiftUI

struct PageEditor: View {
    let library: ComicLibrary
    let comicID: UUID
    let pageID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var deleteConfirmation = false
    private var comic: Comic? { library.comic(comicID) }
    private var page: ComicPage? { comic?.pages.first { $0.id == pageID } }
    private var index: Int { comic?.pages.firstIndex { $0.id == pageID } ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                if let page {
                    Section {
                        PageThumbnail(url: library.imageURL(page, in: comicID), maxPixels: 1200)
                            .aspectRatio(Double(page.width) / Double(page.height), contentMode: .fit)
                            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    }
                    Section("Image") {
                        LabeledContent("Source", value: page.sourceName)
                        LabeledContent("Resolution", value: "\(page.width) × \(page.height)")
                        if index == 0 { Label("This page is the cover", systemImage: "book.closed").foregroundStyle(Palette.ink) }
                        else {
                            Button("Make this the cover", systemImage: "book.closed") {
                                library.update(comicID) { comic in
                                    guard let position = comic.pages.firstIndex(where: { $0.id == pageID }) else { return }
                                    comic.pages.insert(comic.pages.remove(at: position), at: 0)
                                }
                            }
                        }
                    }
                    Section {
                        TextField("Describe what happens on this page…", text: Binding(
                            get: { self.page?.caption ?? "" },
                            set: { value in library.update(comicID) { comic in
                                if let position = comic.pages.firstIndex(where: { $0.id == pageID }) { comic.pages[position].caption = value }
                            } }
                        ), axis: .vertical).lineLimit(3...6)
                    } header: { Text("Image description (optional)") }
                    footer: { Text("Included as alternative text in EPUB for readers using VoiceOver.") }
                    Section {
                        Button("Remove page", systemImage: "trash", role: .destructive) { deleteConfirmation = true }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Palette.paper)
            .navigationTitle("Page \(index + 1)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Remove this page?", isPresented: $deleteConfirmation, titleVisibility: .visible) {
                Button("Remove page", role: .destructive) {
                    if let page { library.deletePage(page, from: comicID) }
                    dismiss()
                }
            } message: { Text("The original image in your library is kept.") }
        }
    }
}
