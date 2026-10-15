import SwiftUI
import UIKit

enum Palette {
    static let paper = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.07, alpha: 1) : UIColor(white: 0.96, alpha: 1)
    })
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.97, alpha: 1) : UIColor(white: 0.06, alpha: 1)
    })
    static let panel = Color(uiColor: .secondarySystemGroupedBackground)
    static let printBlack = Color(white: 0.06)
    static let yellow = Color(red: 1, green: 0.886, blue: 0.235)
    static let red = Color(red: 0.925, green: 0.2, blue: 0.251)
    static let cyan = Color(red: 0.09, green: 0.737, blue: 0.918)
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 1, green: 0.886, blue: 0.235, alpha: 1) : UIColor(white: 0.06, alpha: 1)
    })
}

struct Halftone: View {
    var color: Color = Palette.ink
    var body: some View {
        Canvas { context, size in
            for x in stride(from: 3.0, to: size.width, by: 10) {
                for y in stride(from: 3.0, to: size.height, by: 10) {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(color.opacity(0.14)))
                }
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct ComicChip: View {
    let text: String
    var color: Color = Palette.yellow
    var body: some View {
        Text(text).font(.caption2.weight(.black)).fontWidth(.condensed)
            .foregroundStyle(Palette.printBlack).padding(.horizontal, 8).padding(.vertical, 5)
            .background(color).overlay(Rectangle().stroke(Palette.printBlack, lineWidth: 1.5))
    }
}

extension View {
    func comicPanel(fill: Color = Palette.panel, border: Color = Palette.ink, shadow: CGFloat = 4) -> some View {
        background {
            Rectangle().fill(fill)
                .overlay(Rectangle().stroke(border, lineWidth: 2))
                .shadow(color: border, radius: 0, x: shadow, y: shadow)
        }
    }
    func comicFooter() -> some View {
        background(Palette.paper).overlay(alignment: .top) { Rectangle().fill(Palette.ink).frame(height: 2) }
    }
}

struct PageThumbnail: View {
    let url: URL?
    var maxPixels = 400
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Palette.panel)
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").font(.title2).foregroundStyle(.tertiary)
            }
        }
        .task(id: url) {
            image = nil
            guard let url else { return }
            let loaded = await Task.detached(priority: .userInitiated) {
                try? ImagePipeline.image(at: url, maxPixels: maxPixels)
            }.value
            guard !Task.isCancelled else { return }
            if let loaded { image = UIImage(cgImage: loaded) }
        }
        .accessibilityHidden(true)
    }
}

struct ComicEmblem: View {
    var body: some View {
        ZStack {
            Halftone().frame(width: 280, height: 200)
            cover(color: Palette.cyan, front: false).rotationEffect(.degrees(-16)).offset(x: -35, y: -6)
            cover(color: Palette.red, front: false).rotationEffect(.degrees(14)).offset(x: 36, y: 5)
            cover(color: Palette.yellow, front: true).rotationEffect(.degrees(-3))
        }
        .frame(width: 280, height: 230)
        .accessibilityHidden(true)
    }
    private func cover(color: Color, front: Bool) -> some View {
        VStack(spacing: 9) {
            HStack {
                Text("COMIX").font(.system(size: 24, weight: .black)).fontWidth(.condensed).italic()
                Spacer(minLength: 0)
                Text("#1").font(.system(size: 10, weight: .black, design: .monospaced))
            }
            ZStack {
                Color.white
                Halftone(color: Palette.printBlack)
                if front {
                    Image(systemName: "bolt.fill").font(.system(size: 62, weight: .black)).foregroundStyle(Palette.red)
                        .shadow(color: Palette.printBlack, radius: 0, x: 3, y: 3)
                }
            }.overlay(Rectangle().stroke(Palette.printBlack, lineWidth: 2))
            HStack(spacing: 5) {
                Rectangle().fill(Palette.printBlack).frame(height: 4)
                Rectangle().fill(Palette.printBlack).frame(width: 22, height: 4)
            }
        }.foregroundStyle(Palette.printBlack).padding(12)
            .frame(width: 135, height: 182)
            .comicPanel(fill: color, border: Palette.printBlack, shadow: 5)
    }
}

struct ComicButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.printBlack)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                Rectangle().fill(enabled ? Palette.yellow : Color(white: 0.72))
                    .overlay(Rectangle().stroke(Palette.printBlack, lineWidth: 2))
                    .shadow(color: Palette.printBlack.opacity(enabled ? 1 : 0.35), radius: 0,
                            x: configuration.isPressed ? 0 : 4, y: configuration.isPressed ? 0 : 4)
            }
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title.uppercased(), systemImage: icon).font(.headline.weight(.black)).fontWidth(.condensed)
        }.buttonStyle(ComicButtonStyle())
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareFile: Identifiable { let id = UUID(); let url: URL }
