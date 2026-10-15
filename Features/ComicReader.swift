import SwiftUI
import UIKit

struct ComicReader: View {
    let comic: Comic
    let folder: URL
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID?
    private var ordered: [ComicPage] { comic.direction == .rightToLeft ? comic.pages.reversed() : comic.pages }
    private var pageNumber: Int { (comic.pages.firstIndex { $0.id == selected } ?? 0) + 1 }

    var body: some View {
        NavigationStack {
            TabView(selection: $selected) {
                ForEach(ordered) { page in
                    ZoomablePage(url: folder.appendingPathComponent(page.filename), caption: page.caption)
                        .tag(Optional(page.id))
                }
            }.tabViewStyle(.page(indexDisplayMode: .never)).background(Color.black)
            .navigationTitle(comic.displayTitle).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .bottomBar) {
                    Text("\(pageNumber) / \(comic.pages.count) · Pinch to zoom").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .onAppear { selected = comic.pages.first?.id }
        }
    }
}

private struct ZoomablePage: View {
    let url: URL
    let caption: String
    @State private var image: UIImage?
    @State private var failure = false
    var body: some View {
        Group {
            if let image { ImageScrollView(image: image).accessibilityLabel(caption.isEmpty ? "Comic page. Pinch or double tap to zoom." : caption) }
            else if failure { ContentUnavailableView("Page unavailable", systemImage: "photo", description: Text("Try importing this image again.")) }
            else { ProgressView().tint(.white) }
        }
        .task(id: url) {
            let decoded = await Task.detached(priority: .userInitiated) { try? ImagePipeline.image(at: url, maxPixels: 4096) }.value
            guard !Task.isCancelled else { return }
            if let decoded { image = UIImage(cgImage: decoded) } else { failure = true }
        }
    }
}

private struct ImageScrollView: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ZoomCanvas {
        let view = ZoomCanvas()
        view.minimumZoomScale = 1; view.maximumZoomScale = 5
        view.bouncesZoom = true; view.delegate = context.coordinator
        view.showsVerticalScrollIndicator = false; view.showsHorizontalScrollIndicator = false
        view.imageView.contentMode = .scaleAspectFit
        view.addSubview(view.imageView)
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        return view
    }
    func updateUIView(_ uiView: ZoomCanvas, context: Context) {
        if uiView.imageView.image !== image {
            uiView.setZoomScale(1, animated: false)
            uiView.imageView.image = image
            uiView.setNeedsLayout()
        }
    }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? ZoomCanvas)?.imageView }
        @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? ZoomCanvas else { return }
            if scroll.zoomScale > 1 { scroll.setZoomScale(1, animated: true) }
            else {
                let point = gesture.location(in: scroll.imageView)
                let size = CGSize(width: scroll.bounds.width / 2.5, height: scroll.bounds.height / 2.5)
                scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
            }
        }
    }
    final class ZoomCanvas: UIScrollView {
        let imageView = UIImageView()
        private var previousSize = CGSize.zero
        override func layoutSubviews() {
            super.layoutSubviews()
            if bounds.size != previousSize {
                previousSize = bounds.size
                setZoomScale(1, animated: false)
                imageView.frame = CGRect(origin: .zero, size: bounds.size)
                contentSize = bounds.size
            }
        }
    }
}
