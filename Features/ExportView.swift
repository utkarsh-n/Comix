import SwiftUI
import PDFKit

struct ExportView: View {
    let comic: Comic
    let folder: URL
    @Environment(\.dismiss) private var dismiss
    @State private var format = ExportFormat.epub
    @State private var quality = ExportQuality.balanced
    @State private var progress = 0.0
    @State private var exporting = false
    @State private var output: URL?
    @State private var failure: String?
    @State private var share: ShareFile?
    @State private var preview: ShareFile?
    @State private var exportTask: Task<Void, Never>?
    private let exporter = ComicExporter()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        PageThumbnail(url: comic.pages.first.map { folder.appendingPathComponent($0.filename) })
                            .frame(width: 62, height: 88).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(comic.displayTitle.uppercased()).font(.headline.weight(.black)).fontWidth(.condensed)
                            if !comic.author.isEmpty { Text(comic.author).font(.subheadline).foregroundStyle(.secondary) }
                            Text("\(comic.pages.count) pages").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).comicPanel()
                }.listRowBackground(Color.clear)
                Section {
                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).disabled(exporting)
                    Text(format.detail).font(.subheadline).foregroundStyle(.secondary)
                } header: { Text("Choose a format") }
                Section {
                    Picker("Image quality", selection: $quality) {
                        ForEach(ExportQuality.allCases) { Text($0.rawValue).tag($0) }
                    }.disabled(exporting)
                    Text(quality.detail).font(.subheadline).foregroundStyle(.secondary)
                } header: { Text("File size") }
                footer: {
                    Text(format == .epub ? "EPUB preserves your artwork's proportions on a canvas matching the cover. Oversized images are fitted within Apple Books' image limits." : "Each PDF page matches its image's proportions. No artwork is cropped.")
                }
                if exporting {
                    Section {
                        ProgressView("Exporting pages…", value: progress)
                        Button("Cancel export", role: .cancel) { exportTask?.cancel() }
                    }
                } else if let output {
                    Section {
                        Label("Your \(output.pathExtension.uppercased()) is ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        LabeledContent("File size", value: fileSize(output))
                        Button("Share or open in Books", systemImage: "square.and.arrow.up") { share = ShareFile(url: output) }
                            .accessibilityIdentifier("shareExport")
                        if output.pathExtension == "pdf" {
                            Button("Preview PDF", systemImage: "doc.text.magnifyingglass") { preview = ShareFile(url: output) }
                                .accessibilityIdentifier("previewPDF")
                        }
                    } footer: { Text("Choose Books in the share sheet, or Save to Files. Your export is also saved in Files → On My iPhone → Comix → Exports.") }
                }
                if let failure { Section { Text(failure).foregroundStyle(.red).font(.subheadline) } }
            }
            .scrollContentBackground(.hidden).background(Palette.paper)
            .navigationTitle("Export comic").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(exporting) }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: output == nil ? "Create \(format.rawValue)" : "Create another copy", icon: "book.closed") { runExport() }
                    .disabled(exporting || comic.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("createExport")
                    .padding(20).comicFooter()
            }
            .interactiveDismissDisabled(exporting)
            .sheet(item: $share) { ActivitySheet(url: $0.url) }
            .sheet(item: $preview) { PDFPreview(url: $0.url) }
            .onChange(of: format) { _, _ in output = nil; failure = nil }
            .onChange(of: quality) { _, _ in output = nil; failure = nil }
            .onDisappear { exportTask?.cancel() }
        }
    }

    private func runExport() {
        exporting = true; progress = 0; output = nil; failure = nil
        let selectedFormat = format
        let selectedQuality = quality
        exportTask = Task {
            do {
                output = try await exporter.export(comic, folder: folder, format: selectedFormat, quality: selectedQuality) { fraction in
                    await MainActor.run { progress = fraction }
                }
            } catch is CancellationError { failure = "Export cancelled. Your draft is saved." }
            catch { failure = error.localizedDescription }
            exporting = false
        }
    }
    private func fileSize(_ url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

private struct PDFPreview: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            PDFDocumentView(url: url).ignoresSafeArea(edges: .bottom)
                .navigationTitle("PDF preview").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct PDFDocumentView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
