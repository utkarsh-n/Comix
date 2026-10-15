import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ComicEditor: View {
    let library: ComicLibrary
    let comicID: UUID
    @State private var section = EditorSection.pages
    @State private var arrange = false
    @State private var photoPicker = false
    @State private var filePicker = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var importedCount = 0
    @State private var totalCount = 0
    @State private var sheet: EditorSheet?
    private let importer = ImageImporter()

    private var comic: Comic { library.comic(comicID) ?? Comic() }

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("Editor", selection: $section) {
                ForEach(EditorSection.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).padding(.horizontal, 20).padding(.bottom, 12)
            if section == .pages { pagesList } else { metadataForm }
        }
        .background(Palette.paper)
        .navigationTitle("Comic draft").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !comic.pages.isEmpty {
                    Button("Preview", systemImage: "book") { sheet = .reader }.disabled(importing)
                    if section == .pages {
                        Button(arrange ? "Done" : "Arrange") { arrange.toggle() }.disabled(importing)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if importing {
                    ProgressView("Importing page \(min(importedCount + 1, totalCount)) of \(totalCount)…", value: Double(importedCount), total: Double(max(1, totalCount)))
                        .font(.caption)
                }
                PrimaryButton(title: "Export comic", icon: "square.and.arrow.up") { sheet = .export }
                    .disabled(comic.pages.isEmpty || importing).accessibilityIdentifier("exportComic")
            }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 16).comicFooter()
        }
        .photosPicker(isPresented: $photoPicker, selection: $photos, maxSelectionCount: nil,
                      selectionBehavior: .ordered, matching: .images)
        .onChange(of: photos) { _, items in if !items.isEmpty { importPhotos(items) } }
        .fileImporter(isPresented: $filePicker, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): importFiles(urls)
            case .failure(let error): library.error = error.localizedDescription
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .reader: ComicReader(comic: comic, folder: library.folder(comicID))
            case .export: ExportView(comic: comic, folder: library.folder(comicID))
            case .page(let id): PageEditor(library: library, comicID: comicID, pageID: id)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            PageThumbnail(url: comic.pages.first.map { library.imageURL($0, in: comicID) })
                .frame(width: 54, height: 76).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            VStack(alignment: .leading, spacing: 5) {
                Text(comic.displayTitle.uppercased()).font(.title3.weight(.black)).fontWidth(.condensed)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text("\(comic.pages.count) \(comic.pages.count == 1 ? "page" : "pages") · \(comic.author.isEmpty ? "Add an author in Details" : comic.author)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(20)
    }

    private var pagesList: some View {
        List {
            Section {
                importMenu
                    .listRowBackground(Color.clear)
            }
            if comic.pages.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Bring in your pages", systemImage: "photo.on.rectangle.angled")
                    } description: {
                        Text("Pick images from Photos or Files. Each image becomes one page, in the order you choose.")
                    }.listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(Array(comic.pages.enumerated()), id: \.element.id) { index, page in
                        Button { sheet = .page(page.id) } label: {
                            HStack(spacing: 16) {
                                PageThumbnail(url: library.imageURL(page, in: comicID))
                                    .frame(width: 60, height: 84).overlay(Rectangle().stroke(Palette.ink, lineWidth: 1.5))
                                VStack(alignment: .leading, spacing: 6) {
                                    ViewThatFits(in: .horizontal) {
                                        HStack {
                                            pageNumber(index)
                                            if index == 0 { ComicChip(text: "COVER") }
                                        }.fixedSize(horizontal: true, vertical: false)
                                        VStack(alignment: .leading, spacing: 5) {
                                            pageNumber(index)
                                            if index == 0 { ComicChip(text: "COVER") }
                                        }
                                    }
                                    Text(page.sourceName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    Text("\(page.width) × \(page.height)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if !arrange { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary) }
                            }.padding(12).foregroundStyle(.primary).comicPanel(shadow: 3)
                        }.buttonStyle(.plain).disabled(importing)
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 7, leading: 4, bottom: 7, trailing: 7))
                    }
                    .onMove { source, destination in library.update(comicID) { $0.pages.move(fromOffsets: source, toOffset: destination) } }
                    .moveDisabled(importing)
                } footer: {
                    Text(arrange ? "Drag the handles to change reading order." : "The first page is your cover. Tap a page for a closer look, or use Arrange to reorder.")
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(arrange ? .active : .inactive))
    }

    private func pageNumber(_ index: Int) -> some View {
        HStack(spacing: 6) {
            Text(String(format: "%02d", index + 1)).font(.title2.weight(.black)).fontWidth(.condensed).monospacedDigit()
            Text("PAGE").font(.caption.weight(.black)).foregroundStyle(.secondary)
        }
    }

    private var importMenu: some View {
        Menu {
            Button("Choose from Photos", systemImage: "photo.on.rectangle") { photoPicker = true }
            Button("Choose from Files", systemImage: "folder") { filePicker = true }
        } label: {
            Label("Add pages", systemImage: "plus.circle.fill")
                .font(.headline.weight(.black)).fontWidth(.condensed)
                .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .foregroundStyle(Palette.printBlack).comicPanel(fill: Palette.cyan, border: Palette.printBlack, shadow: 3)
        }.disabled(importing).accessibilityIdentifier("addPages")
    }

    private var metadataForm: some View {
        Form {
            Section("Book details") {
                TextField("Title", text: text(\.title)).accessibilityIdentifier("comicTitle")
                TextField("Author or creator", text: text(\.author)).textContentType(.name)
                TextField("Series (optional)", text: text(\.series))
                TextField("Issue or volume number (optional)", text: text(\.volume)).keyboardType(.decimalPad)
            }
            Section("Description") {
                TextField("What's this issue about?", text: text(\.synopsis), axis: .vertical).lineLimit(3...6)
            }
            Section {
                Picker("Page direction", selection: Binding(get: { comic.direction }, set: { value in library.update(comicID) { $0.direction = value } })) {
                    ForEach(ReadingDirection.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("Language", selection: text(\.language)) {
                    ForEach(Self.languages, id: \.0) { code, name in Text(name).tag(code) }
                }
            } header: { Text("Reading") }
            footer: { Text("EPUB includes these book details. PDF includes the title, author, description, and series. Text within your images stays as artwork.") }
        }.scrollContentBackground(.hidden)
    }
    private func text(_ keyPath: WritableKeyPath<Comic, String>) -> Binding<String> {
        Binding(get: { comic[keyPath: keyPath] }, set: { value in library.update(comicID) { $0[keyPath: keyPath] = value } })
    }
    private static let languages = [("en", "English"), ("hi", "Hindi"), ("es", "Spanish"), ("fr", "French"), ("de", "German"), ("it", "Italian"), ("ja", "Japanese"), ("ko", "Korean"), ("zh", "Chinese"), ("pt", "Portuguese"), ("ar", "Arabic")]

    private func beginImport(count: Int) { importing = true; importedCount = 0; totalCount = count; arrange = false }
    private func importPhotos(_ items: [PhotosPickerItem]) {
        beginImport(count: items.count)
        Task {
            var failures: [String] = []
            for (index, item) in items.enumerated() {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw ComixError.message("Photo \(index + 1) could not be downloaded.") }
                    let page = try await importer.importData(data, into: library.folder(comicID), name: "Photo \(index + 1)")
                    library.append(page, to: comicID)
                } catch { failures.append("Photo \(index + 1): \(error.localizedDescription)") }
                importedCount += 1
            }
            photos = []
            importing = false
            if !failures.isEmpty { library.error = "\(failures.count) photo(s) could not be imported. The other pages were saved.\n\n\(failures.prefix(3).joined(separator: "\n"))" }
        }
    }
    private func importFiles(_ urls: [URL]) {
        // Files does not report selection order, so use natural filename order.
        let ordered = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        beginImport(count: ordered.count)
        Task {
            var failures: [String] = []
            for url in ordered {
                do { library.append(try await importer.importFile(url, into: library.folder(comicID)), to: comicID) }
                catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
                importedCount += 1
            }
            importing = false
            if !failures.isEmpty { library.error = "\(failures.count) image(s) could not be imported. The other pages were saved.\n\n\(failures.prefix(3).joined(separator: "\n"))" }
        }
    }
}

private enum EditorSection: String, CaseIterable, Identifiable { case pages = "Pages", details = "Details"; var id: Self { self } }
private enum EditorSheet: Identifiable {
    case reader, export, page(UUID)
    var id: String { switch self { case .reader: "reader"; case .export: "export"; case .page(let id): id.uuidString } }
}
