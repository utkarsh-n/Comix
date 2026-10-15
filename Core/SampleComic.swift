import UIKit

/// Original three-page space adventure, drawn as inked comic art at export resolution.
enum SampleComic {
    private static let ink = UIColor(red: 0.035, green: 0.035, blue: 0.045, alpha: 1)
    private static let yellow = UIColor(red: 1, green: 226 / 255, blue: 60 / 255, alpha: 1)
    private static let red = UIColor(red: 236 / 255, green: 51 / 255, blue: 64 / 255, alpha: 1)
    private static let cyan = UIColor(red: 23 / 255, green: 188 / 255, blue: 234 / 255, alpha: 1)

    static func make(in folder: URL) async throws -> [ComicPage] {
        try await Task.detached(priority: .userInitiated) {
            try (0..<3).map { index in
                try autoreleasepool {
                    let url = folder.appendingPathComponent("sample-\(index + 1).png")
                    let image = draw(index)
                    guard let data = image.pngData() else { throw ComixError.message("Could not create the sample.") }
                    try data.write(to: url)
                    return ComicPage(filename: url.lastPathComponent, sourceName: "Sample page \(index + 1)",
                                     width: 900, height: 1280, caption: [
                                        "A fearless explorer answers a mysterious signal from the edge of space.",
                                        "On a strange moon, the explorer discovers a friendly alien with a broken transmitter.",
                                        "Together they repair the transmitter and send a new signal across the stars."
                                     ][index])
                }
            }
        }.value
    }

    private static func draw(_ index: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 900, height: 1280), format: format).image { renderer in
            let c = renderer.cgContext
            fill(c, CGRect(x: 0, y: 0, width: 900, height: 1280), .white)
            if index == 0 { cover(c) }
            else if index == 1 { encounter(c) }
            else { finale(c) }
            fill(c, CGRect(x: 28, y: 1210, width: 844, height: 42), ink)
            label("COMIX ORIGINAL • FIRST CONTACT", in: CGRect(x: 48, y: 1218, width: 650, height: 30), size: 21, color: .white)
            label("0\(index + 1)", in: CGRect(x: 791, y: 1212, width: 65, height: 40), size: 30, color: yellow, align: .right)
        }
    }

    private static func cover(_ c: CGContext) {
        let bounds = CGRect(x: 28, y: 28, width: 844, height: 1162)
        fill(c, bounds, yellow)
        dots(c, in: bounds, color: ink.withAlphaComponent(0.16), step: 24, radius: 3)
        c.saveGState(); c.clip(to: bounds)
        burst(c, center: CGPoint(x: 500, y: 729), outer: 760, inner: 225, points: 19, color: red)
        polygon(c, [CGPoint(x: 55, y: 528), CGPoint(x: 813, y: 433), CGPoint(x: 960, y: 1022), CGPoint(x: 131, y: 1163)], color: ink)
        stars(c, in: CGRect(x: 124, y: 455, width: 685, height: 685))
        ellipse(c, CGRect(x: 564, y: 585, width: 232, height: 232), color: cyan, line: 10)
        ellipse(c, CGRect(x: 700, y: 621, width: 34, height: 34), color: ink, line: 0)
        ellipse(c, CGRect(x: 603, y: 724, width: 56, height: 29), color: ink, line: 0)
        line(c, [CGPoint(x: 543, y: 775), CGPoint(x: 811, y: 638)], color: .white, width: 18)
        astronaut(c, at: CGPoint(x: 449, y: 898), scale: 2.05)
        c.restoreGState()
        fill(c, CGRect(x: 28, y: 28, width: 844, height: 54), ink)
        label("COMIX PRESENTS", in: CGRect(x: 51, y: 37, width: 575, height: 40), size: 30, color: yellow)
        label("ISSUE 001", in: CGRect(x: 656, y: 38, width: 190, height: 40), size: 28, color: .white, align: .right)
        // A white inset behind the masthead keeps the title legible over the burst.
        fill(c, CGRect(x: 55, y: 107, width: 790, height: 304), yellow)
        label("FIRST", in: CGRect(x: 64, y: 105, width: 773, height: 135), size: 142, color: ink, align: .center)
        label("CONTACT", in: CGRect(x: 61, y: 230, width: 778, height: 150), size: 137, color: red, align: .center, outline: true)
        caption(c, "ONE SIGNAL.\nA WHOLE NEW UNIVERSE.", rect: CGRect(x: 83, y: 440, width: 411, height: 111), color: .white, size: 33)
        polygon(c, [CGPoint(x: 627, y: 948), CGPoint(x: 851, y: 928), CGPoint(x: 854, y: 1133), CGPoint(x: 627, y: 1155)], color: yellow, line: 8)
        label("A 3-PAGE\nSPACE\nADVENTURE", in: CGRect(x: 651, y: 970, width: 179, height: 165), size: 36, color: ink, align: .center)
        stroke(c, bounds, width: 10)
    }

    private static func encounter(_ c: CGContext) {
        header(c, subtitle: "THE SIGNAL")
        let top = CGRect(x: 28, y: 112, width: 844, height: 304)
        panel(c, top, color: ink) {
            stars(c, in: top)
            ellipse(c, CGRect(x: 599, y: 184, width: 225, height: 225), color: cyan, line: 8)
            ellipse(c, CGRect(x: 742, y: 247, width: 44, height: 25), color: ink, line: 0)
            ship(c, at: CGPoint(x: 306, y: 279), scale: 1.12)
            caption(c, "AT THE EDGE OF THE STAR MAP…", rect: CGRect(x: 44, y: 128, width: 441, height: 52), color: yellow, size: 26)
            balloon(c, "THAT SIGNAL…\nIT'S COMING FROM\nTHE MOON!", rect: CGRect(x: 548, y: 128, width: 283, height: 131), tail: CGPoint(x: 424, y: 278), size: 29)
        }
        let middle = CGRect(x: 28, y: 436, width: 844, height: 335)
        panel(c, middle, color: cyan) {
            dots(c, in: middle, color: ink.withAlphaComponent(0.13), step: 23, radius: 3)
            polygon(c, [CGPoint(x: 28, y: 685), CGPoint(x: 241, y: 554), CGPoint(x: 407, y: 694), CGPoint(x: 689, y: 554), CGPoint(x: 872, y: 681), CGPoint(x: 872, y: 771), CGPoint(x: 28, y: 771)], color: yellow, line: 8)
            line(c, [CGPoint(x: 477, y: 759), CGPoint(x: 627, y: 725), CGPoint(x: 737, y: 730)], color: ink, width: 6)
            astronaut(c, at: CGPoint(x: 268, y: 678), scale: 0.85)
            alien(c, at: CGPoint(x: 625, y: 685), scale: 0.88)
            balloon(c, "HELLO?", rect: CGRect(x: 75, y: 467, width: 227, height: 90), tail: CGPoint(x: 260, y: 590), size: 39)
            balloon(c, "FINALLY!\nSOMEONE HEARD ME.", rect: CGRect(x: 451, y: 462, width: 353, height: 130), tail: CGPoint(x: 612, y: 625), size: 31)
        }
        let bottom = CGRect(x: 28, y: 791, width: 844, height: 399)
        panel(c, bottom, color: yellow) {
            burst(c, center: CGPoint(x: 432, y: 1037), outer: 680, inner: 135, points: 20, color: red)
            transmitter(c, at: CGPoint(x: 436, y: 1042), scale: 1)
            line(c, [CGPoint(x: 427, y: 867), CGPoint(x: 392, y: 906), CGPoint(x: 426, y: 901), CGPoint(x: 390, y: 953)], color: cyan, width: 14)
            balloon(c, "MY TRANSMITTER\nIS BUSTED!", rect: CGRect(x: 59, y: 824, width: 325, height: 123), tail: CGPoint(x: 347, y: 1017), size: 35)
            balloon(c, "THEN LET'S\nFIX IT.", rect: CGRect(x: 560, y: 858, width: 248, height: 135), tail: CGPoint(x: 571, y: 1073), size: 39)
            label("ZZZT!", in: CGRect(x: 76, y: 1040, width: 263, height: 108), size: 84, color: .white, outline: true)
        }
    }

    private static func finale(_ c: CGContext) {
        header(c, subtitle: "LOUD AND CLEAR")
        let top = CGRect(x: 28, y: 112, width: 844, height: 278)
        panel(c, top, color: yellow) {
            dots(c, in: top, color: ink.withAlphaComponent(0.18), step: 21, radius: 3)
            transmitter(c, at: CGPoint(x: 427, y: 290), scale: 0.75)
            polygon(c, [CGPoint(x: 359, y: 269), CGPoint(x: 328, y: 252), CGPoint(x: 291, y: 293), CGPoint(x: 321, y: 311)], color: cyan, line: 7)
            polygon(c, [CGPoint(x: 490, y: 274), CGPoint(x: 540, y: 245), CGPoint(x: 563, y: 283), CGPoint(x: 513, y: 312)], color: red, line: 7)
            caption(c, "ONE QUICK REPAIR LATER…", rect: CGRect(x: 45, y: 128, width: 408, height: 49), color: .white, size: 26)
            label("CLICK!", in: CGRect(x: 585, y: 205, width: 259, height: 94), size: 75, color: red, outline: true)
        }
        let main = CGRect(x: 28, y: 410, width: 844, height: 780)
        panel(c, main, color: ink) {
            stars(c, in: main)
            burst(c, center: CGPoint(x: 473, y: 785), outer: 1000, inner: 330, points: 22, color: cyan)
            ellipse(c, CGRect(x: 138, y: 655, width: 640, height: 640), color: yellow, line: 10)
            dots(c, in: CGRect(x: 147, y: 1035, width: 614, height: 155), color: ink.withAlphaComponent(0.2), step: 26, radius: 4)
            line(c, [CGPoint(x: 92, y: 624), CGPoint(x: 249, y: 690)], color: .white, width: 12)
            line(c, [CGPoint(x: 768, y: 487), CGPoint(x: 623, y: 669)], color: .white, width: 12)
            label("WE'RE LIVE!", in: CGRect(x: 56, y: 449, width: 788, height: 127), size: 106, color: red, align: .center, outline: true)
            astronaut(c, at: CGPoint(x: 302, y: 955), scale: 1.17)
            alien(c, at: CGPoint(x: 622, y: 977), scale: 1.29)
            transmitter(c, at: CGPoint(x: 466, y: 1058), scale: 0.83)
            balloon(c, "ANYONE\nOUT THERE?", rect: CGRect(x: 77, y: 599, width: 339, height: 144), tail: CGPoint(x: 310, y: 814), size: 40)
            balloon(c, "NOW WE\nFIND OUT.", rect: CGRect(x: 498, y: 620, width: 321, height: 137), tail: CGPoint(x: 629, y: 831), size: 40)
            caption(c, "THE ADVENTURE STARTS HERE.", rect: CGRect(x: 89, y: 1104, width: 722, height: 63), color: .white, size: 38)
        }
    }

    private static func header(_ c: CGContext, subtitle: String) {
        fill(c, CGRect(x: 28, y: 28, width: 844, height: 64), ink)
        label("FIRST CONTACT", in: CGRect(x: 45, y: 35, width: 443, height: 51), size: 45, color: yellow)
        label(subtitle, in: CGRect(x: 484, y: 46, width: 366, height: 40), size: 29, color: .white, align: .right)
    }

    private static func panel(_ c: CGContext, _ rect: CGRect, color: UIColor, draw: () -> Void) {
        c.saveGState(); c.clip(to: rect); fill(c, rect, color); draw(); c.restoreGState()
        stroke(c, rect, width: 9)
    }

    private static func astronaut(_ c: CGContext, at point: CGPoint, scale: CGFloat) {
        c.saveGState(); c.translateBy(x: point.x, y: point.y); c.scaleBy(x: scale, y: scale)
        // Red flight scarf and yellow pressure suit: an original, unmistakable silhouette.
        polygon(c, [CGPoint(x: 36, y: -75), CGPoint(x: 128, y: -119), CGPoint(x: 109, y: -72), CGPoint(x: 151, y: -57), CGPoint(x: 52, y: -35)], color: red, line: 5)
        polygon(c, [CGPoint(x: -39, y: 18), CGPoint(x: -12, y: 21), CGPoint(x: -26, y: 103), CGPoint(x: -56, y: 103)], color: yellow, line: 6)
        polygon(c, [CGPoint(x: 13, y: 20), CGPoint(x: 42, y: 13), CGPoint(x: 65, y: 100), CGPoint(x: 35, y: 100)], color: yellow, line: 6)
        fill(c, CGRect(x: -58, y: 91, width: 43, height: 23), ink)
        fill(c, CGRect(x: 31, y: 91, width: 47, height: 23), ink)
        polygon(c, [CGPoint(x: -43, y: -60), CGPoint(x: 43, y: -60), CGPoint(x: 51, y: 33), CGPoint(x: -49, y: 33)], color: yellow, line: 6)
        polygon(c, [CGPoint(x: -45, y: -55), CGPoint(x: -72, y: -39), CGPoint(x: -103, y: 14), CGPoint(x: -78, y: 29), CGPoint(x: -41, y: -16)], color: yellow, line: 6)
        polygon(c, [CGPoint(x: 42, y: -57), CGPoint(x: 71, y: -43), CGPoint(x: 104, y: -9), CGPoint(x: 82, y: 15), CGPoint(x: 46, y: -15)], color: yellow, line: 6)
        ellipse(c, CGRect(x: -108, y: 7, width: 30, height: 31), color: red, line: 5)
        ellipse(c, CGRect(x: 81, y: -12, width: 32, height: 31), color: red, line: 5)
        fill(c, CGRect(x: -46, y: 12, width: 92, height: 14), ink)
        polygon(c, [CGPoint(x: 1, y: -46), CGPoint(x: 24, y: -18), CGPoint(x: 1, y: 1), CGPoint(x: -22, y: -18)], color: red, line: 4)
        ellipse(c, CGRect(x: -53, y: -143, width: 107, height: 98), color: .white, line: 7)
        ellipse(c, CGRect(x: -44, y: -126, width: 88, height: 63), color: cyan, line: 6)
        line(c, [CGPoint(x: -29, y: -101), CGPoint(x: 16, y: -119)], color: .white, width: 7)
        fill(c, CGRect(x: -51, y: -60, width: 101, height: 12), red)
        ellipse(c, CGRect(x: -61, y: -115, width: 18, height: 29), color: yellow, line: 4)
        ellipse(c, CGRect(x: 43, y: -115, width: 18, height: 29), color: yellow, line: 4)
        c.restoreGState()
    }

    private static func alien(_ c: CGContext, at point: CGPoint, scale: CGFloat) {
        c.saveGState(); c.translateBy(x: point.x, y: point.y); c.scaleBy(x: scale, y: scale)
        polygon(c, [CGPoint(x: -33, y: -17), CGPoint(x: 34, y: -17), CGPoint(x: 51, y: 63), CGPoint(x: -50, y: 63)], color: red, line: 6)
        line(c, [CGPoint(x: -22, y: 56), CGPoint(x: -29, y: 83), CGPoint(x: -48, y: 85)], color: ink, width: 11)
        line(c, [CGPoint(x: 23, y: 56), CGPoint(x: 30, y: 83), CGPoint(x: 49, y: 85)], color: ink, width: 11)
        line(c, [CGPoint(x: -32, y: 2), CGPoint(x: -67, y: 20), CGPoint(x: -81, y: 2)], color: cyan, width: 17)
        line(c, [CGPoint(x: 33, y: 2), CGPoint(x: 67, y: -7), CGPoint(x: 77, y: -32)], color: cyan, width: 17)
        ellipse(c, CGRect(x: -62, y: -121, width: 125, height: 113), color: cyan, line: 7)
        line(c, [CGPoint(x: -30, y: -114), CGPoint(x: -43, y: -153)], color: ink, width: 7)
        line(c, [CGPoint(x: 31, y: -114), CGPoint(x: 44, y: -153)], color: ink, width: 7)
        ellipse(c, CGRect(x: -55, y: -169, width: 25, height: 25), color: yellow, line: 5)
        ellipse(c, CGRect(x: 32, y: -169, width: 25, height: 25), color: yellow, line: 5)
        ellipse(c, CGRect(x: -39, y: -84, width: 30, height: 37), color: .white, line: 4)
        ellipse(c, CGRect(x: 10, y: -84, width: 30, height: 37), color: .white, line: 4)
        ellipse(c, CGRect(x: -26, y: -73, width: 13, height: 21), color: ink, line: 0)
        ellipse(c, CGRect(x: 14, y: -73, width: 13, height: 21), color: ink, line: 0)
        c.setStrokeColor(ink.cgColor); c.setLineWidth(5)
        c.move(to: CGPoint(x: -19, y: -34)); c.addQuadCurve(to: CGPoint(x: 23, y: -34), control: CGPoint(x: 2, y: -7)); c.strokePath()
        polygon(c, [CGPoint(x: 0, y: 0), CGPoint(x: 16, y: 19), CGPoint(x: 0, y: 38), CGPoint(x: -16, y: 19)], color: yellow, line: 4)
        c.restoreGState()
    }

    private static func ship(_ c: CGContext, at point: CGPoint, scale: CGFloat) {
        c.saveGState(); c.translateBy(x: point.x, y: point.y); c.scaleBy(x: scale, y: scale)
        polygon(c, [CGPoint(x: -104, y: -7), CGPoint(x: -197, y: -47), CGPoint(x: -179, y: -6), CGPoint(x: -228, y: 17), CGPoint(x: -107, y: 22)], color: red, line: 6)
        polygon(c, [CGPoint(x: -89, y: -8), CGPoint(x: -121, y: -66), CGPoint(x: 36, y: -21), CGPoint(x: 125, y: 12), CGPoint(x: -103, y: 43)], color: .white, line: 7)
        polygon(c, [CGPoint(x: -6, y: -30), CGPoint(x: 41, y: -28), CGPoint(x: 64, y: -5), CGPoint(x: -7, y: 3)], color: cyan, line: 5)
        line(c, [CGPoint(x: -67, y: 23), CGPoint(x: 36, y: 12)], color: red, width: 11)
        c.restoreGState()
    }

    private static func transmitter(_ c: CGContext, at point: CGPoint, scale: CGFloat) {
        c.saveGState(); c.translateBy(x: point.x, y: point.y); c.scaleBy(x: scale, y: scale)
        line(c, [CGPoint(x: 0, y: -29), CGPoint(x: 0, y: -119)], color: ink, width: 9)
        polygon(c, [CGPoint(x: -68, y: -151), CGPoint(x: 73, y: -151), CGPoint(x: 34, y: -99), CGPoint(x: -24, y: -99)], color: .white, line: 7)
        line(c, [CGPoint(x: 2, y: -150), CGPoint(x: 19, y: -191)], color: ink, width: 7)
        ellipse(c, CGRect(x: 11, y: -205, width: 20, height: 20), color: red, line: 5)
        fill(c, CGRect(x: -76, y: -38, width: 152, height: 108), cyan)
        stroke(c, CGRect(x: -76, y: -38, width: 152, height: 108), width: 8)
        fill(c, CGRect(x: -55, y: -18, width: 63, height: 43), ink)
        line(c, [CGPoint(x: -45, y: 5), CGPoint(x: -33, y: -8), CGPoint(x: -21, y: 12), CGPoint(x: -9, y: 0)], color: yellow, width: 4)
        ellipse(c, CGRect(x: 24, y: -17, width: 27, height: 27), color: red, line: 5)
        line(c, [CGPoint(x: -55, y: 43), CGPoint(x: 52, y: 43)], color: ink, width: 7)
        c.restoreGState()
    }

    private static func caption(_ c: CGContext, _ text: String, rect: CGRect, color: UIColor, size: CGFloat) {
        fill(c, rect.offsetBy(dx: 5, dy: 5), ink)
        fill(c, rect, color); stroke(c, rect, width: 5)
        label(text, in: rect.insetBy(dx: 12, dy: 7), size: size, color: ink)
    }

    private static func balloon(_ c: CGContext, _ text: String, rect: CGRect, tail: CGPoint, size: CGFloat) {
        let base = CGPoint(x: min(max(tail.x, rect.minX + 40), rect.maxX - 40), y: rect.maxY - 18)
        polygon(c, [CGPoint(x: base.x - 22, y: base.y), tail, CGPoint(x: base.x + 22, y: base.y)], color: .white, line: 5)
        ellipse(c, rect, color: .white, line: 5)
        label(text, in: rect.insetBy(dx: 20, dy: 17), size: size, color: ink, align: .center, fit: true)
    }

    private static func label(_ text: String, in rect: CGRect, size: CGFloat, color: UIColor, align: NSTextAlignment = .left, outline: Bool = false, fit: Bool = false) {
        let style = NSMutableParagraphStyle(); style.alignment = align; style.lineSpacing = -2
        var actualSize = size
        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color, .paragraphStyle: style]
        var measured = CGRect.zero
        repeat {
            attributes[.font] = UIFont(name: "AvenirNextCondensed-Heavy", size: actualSize) ?? UIFont.systemFont(ofSize: actualSize, weight: .black)
            measured = (text as NSString).boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                                      options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            if !fit || measured.height <= rect.height || actualSize <= 12 { break }
            actualSize -= 1
        } while true
        if outline { attributes[.strokeColor] = ink; attributes[.strokeWidth] = -4 }
        let textRect = fit ? CGRect(x: rect.minX, y: rect.minY + max(0, (rect.height - measured.height) / 2), width: rect.width, height: rect.height) : rect
        (text as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private static func fill(_ c: CGContext, _ rect: CGRect, _ color: UIColor) {
        c.setFillColor(color.cgColor); c.fill(rect)
    }
    private static func stroke(_ c: CGContext, _ rect: CGRect, width: CGFloat) {
        c.setStrokeColor(ink.cgColor); c.setLineWidth(width); c.stroke(rect.insetBy(dx: width / 2, dy: width / 2))
    }
    private static func ellipse(_ c: CGContext, _ rect: CGRect, color: UIColor, line: CGFloat) {
        c.setFillColor(color.cgColor); c.setStrokeColor(ink.cgColor); c.setLineWidth(line)
        c.addEllipse(in: rect); c.drawPath(using: line > 0 ? .fillStroke : .fill)
    }
    private static func polygon(_ c: CGContext, _ points: [CGPoint], color: UIColor, line: CGFloat = 0) {
        guard let first = points.first else { return }
        c.beginPath(); c.move(to: first); for point in points.dropFirst() { c.addLine(to: point) }; c.closePath()
        c.setFillColor(color.cgColor); c.setStrokeColor(ink.cgColor); c.setLineWidth(line); c.setLineJoin(.round)
        c.drawPath(using: line > 0 ? .fillStroke : .fill)
    }
    private static func line(_ c: CGContext, _ points: [CGPoint], color: UIColor, width: CGFloat) {
        guard let first = points.first else { return }
        c.beginPath(); c.move(to: first); for point in points.dropFirst() { c.addLine(to: point) }
        c.setStrokeColor(color.cgColor); c.setLineWidth(width); c.setLineCap(.round); c.strokePath()
    }
    private static func burst(_ c: CGContext, center: CGPoint, outer: CGFloat, inner: CGFloat, points: Int, color: UIColor) {
        let vertices = (0..<(points * 2)).map { i -> CGPoint in
            let angle = CGFloat(i) * .pi / CGFloat(points)
            let radius = i.isMultiple(of: 2) ? outer : inner
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }
        polygon(c, vertices, color: color)
    }
    private static func dots(_ c: CGContext, in rect: CGRect, color: UIColor, step: CGFloat, radius: CGFloat) {
        c.saveGState(); c.clip(to: rect); c.setFillColor(color.cgColor)
        var row = 0
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX + (row.isMultiple(of: 2) ? 0 : step / 2)
            while x < rect.maxX { c.fillEllipse(in: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)); x += step }
            row += 1; y += step
        }
        c.restoreGState()
    }
    private static func stars(_ c: CGContext, in rect: CGRect) {
        for i in 0..<30 {
            let x = rect.minX + CGFloat((i * 137 + 41) % max(Int(rect.width), 1))
            let y = rect.minY + CGFloat((i * 191 + 13) % max(Int(rect.height), 1))
            let r: CGFloat = i.isMultiple(of: 5) ? 9 : 3
            if r == 9 {
                polygon(c, [CGPoint(x: x, y: y - r), CGPoint(x: x + 3, y: y - 3), CGPoint(x: x + r, y: y), CGPoint(x: x + 3, y: y + 3), CGPoint(x: x, y: y + r), CGPoint(x: x - 3, y: y + 3), CGPoint(x: x - r, y: y), CGPoint(x: x - 3, y: y - 3)], color: .white)
            } else { ellipse(c, CGRect(x: x, y: y, width: r * 2, height: r * 2), color: .white, line: 0) }
        }
    }
}
