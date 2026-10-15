import SwiftUI

struct LibraryView: View {
    let library: ComicLibrary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 39
    @State private var path: [UUID] = []
    @State private var deleting: Comic?
    @State private var creatingSample = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if library.comics.isEmpty { emptyLibrary }
                else { bookshelf }
            }
            .background(Palette.paper)
            .navigationTitle("Comix").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("COMIX").font(.title3.weight(.black)).fontWidth(.condensed).italic()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New comic", systemImage: "plus") { create() }
                        Button("Load sample issue", systemImage: "bolt.fill") { sample() }.disabled(creatingSample)
                    } label: { Image(systemName: "plus").fontWeight(.bold) }
                        .accessibilityLabel("New comic").accessibilityIdentifier("newComic")
                }
            }
            .navigationDestination(for: UUID.self) { id in ComicEditor(library: library, comicID: id) }
            .confirmationDialog("Delete \(deleting?.displayTitle ?? "comic")?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }
            ), titleVisibility: .visible) {
                Button("Delete draft", role: .destructive) {
                    guard let comic = deleting else { return }
                    do { try library.delete(comic.id) } catch { library.error = error.localizedDescription }
                    deleting = nil
                }
            } message: { Text("This removes the draft and its copied pages. Your original photos and exported books are kept.") }
        }
    }

    private var emptyLibrary: some View {
        ScrollView {
            VStack(spacing: 20) {
                masthead
                ComicEmblem().padding(.top, 4)
                VStack(spacing: 10) {
                    Text("YOUR PAGES.\nYOUR COMIC.")
                        .font(.system(size: headlineSize, weight: .black)).fontWidth(.condensed).italic()
                        .multilineTextAlignment(.center).lineSpacing(-2)
                    Text("Pick your pages. Set the order.\nExport PDF or EPUB.")
                        .font(.body.weight(.medium)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                VStack(spacing: 14) {
                    PrimaryButton(title: "New comic", icon: "plus") { create() }
                    Button { sample() } label: {
                        if creatingSample { ProgressView() }
                        else { Label("Load a sample issue", systemImage: "bolt.fill").font(.subheadline.weight(.bold)) }
                    }.disabled(creatingSample).accessibilityIdentifier("sampleComic")
                }.frame(maxWidth: 360).padding(.top, 6)
                Text("ONE IMAGE = ONE PAGE").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(.secondary)
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 32).frame(maxWidth: .infinity)
        }
    }

    private var bookshelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                masthead
                ViewThatFits(in: .horizontal) {
                    HStack {
                        longboxTitle.fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 12)
                        draftCount.fixedSize(horizontal: true, vertical: false)
                    }
                    VStack(alignment: .leading, spacing: 10) { longboxTitle; draftCount }
                }.frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 22)], alignment: .leading, spacing: 28) {
                    ForEach(library.comics.sorted { $0.modified > $1.modified }) { comic in
                        Button { path.append(comic.id) } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                PageThumbnail(url: comic.pages.first.map { library.imageURL($0, in: comic.id) })
                                    .aspectRatio(0.7, contentMode: .fit)
                                    .overlay(alignment: .bottomLeading) {
                                        ComicChip(text: "\(comic.pages.count) PAGES").padding(8)
                                    }
                                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 2) }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(comic.displayTitle.uppercased()).font(.headline.weight(.black)).fontWidth(.condensed).foregroundStyle(.primary).lineLimit(2)
                                    Text(comic.author.isEmpty ? "DRAFT ISSUE" : comic.author)
                                        .font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                                }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
                            }.comicPanel()
                        }.buttonStyle(.plain)
                        .contextMenu { Button("Delete draft", systemImage: "trash", role: .destructive) { deleting = comic } }
                    }
                }
                Text("Drafts autosave. Your next issue starts here.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
            }.padding(24)
        }
    }

    private var longboxTitle: some View { Text("THE LONGBOX").font(.title2.weight(.black)).fontWidth(.condensed) }
    private var draftCount: some View {
        ComicChip(text: "\(library.comics.count) \(library.comics.count == 1 ? "DRAFT" : "DRAFTS")", color: Palette.cyan)
    }

    private var masthead: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("IMAGE TO COMIC PRESS").font(.system(size: 10, weight: .black, design: .monospaced)).tracking(0.5)
                Text("COMIX").font(.system(size: 52, weight: .black)).fontWidth(.condensed).italic()
            }
            Spacer(minLength: 4)
            VStack(spacing: 4) {
                Text("PDF").font(.headline.weight(.black)).fontWidth(.condensed)
                Rectangle().fill(Palette.printBlack).frame(width: 34, height: 2)
                Text("EPUB").font(.headline.weight(.black)).fontWidth(.condensed)
            }.padding(9).overlay(Rectangle().stroke(Palette.printBlack, lineWidth: 2)).rotationEffect(.degrees(3))
        }.foregroundStyle(Palette.printBlack).padding(16)
            .background { Halftone(color: Palette.printBlack) }
            .comicPanel(fill: Palette.yellow, border: Palette.printBlack)
    }

    private func create() {
        do { path.append(try library.create().id) } catch { library.error = error.localizedDescription }
    }
    private func sample() {
        creatingSample = true
        Task {
            do {
                let comic = try library.create()
                library.update(comic.id) { $0.title = "First Contact"; $0.author = "Comix"; $0.synopsis = "An impossible signal. An uncharted moon. An unexpected ally. A three-page sample issue." }
                let pages = try await SampleComic.make(in: library.folder(comic.id))
                for page in pages { library.append(page, to: comic.id) }
                path.append(comic.id)
            } catch { library.error = error.localizedDescription }
            creatingSample = false
        }
    }
}
