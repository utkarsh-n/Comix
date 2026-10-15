import AppKit

// Reproducible 1024px COMIX icon. All shapes are opaque, drawn in ink and process colors.
// swift -module-cache-path /private/tmp/ComixIconCache generate-icon.swift /path/to/AppIcon.png
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let ink = NSColor(red: 0.035, green: 0.035, blue: 0.045, alpha: 1)
let yellow = NSColor(red: 1, green: 226 / 255, blue: 60 / 255, alpha: 1)
let red = NSColor(red: 236 / 255, green: 51 / 255, blue: 64 / 255, alpha: 1)
let cyan = NSColor(red: 23 / 255, green: 188 / 255, blue: 234 / 255, alpha: 1)
func polygon(_ points: [CGPoint], color: NSColor, width: CGFloat = 0) {
    context.beginPath(); context.move(to: points[0])
    for point in points.dropFirst() { context.addLine(to: point) }
    context.closePath(); context.setFillColor(color.cgColor)
    context.setStrokeColor(ink.cgColor); context.setLineWidth(width); context.setLineJoin(.miter)
    context.drawPath(using: width > 0 ? .fillStroke : .fill)
}
context.setFillColor(yellow.cgColor); context.fill(CGRect(x: 0, y: 0, width: size, height: size))
// Large Ben-Day dots create texture without obscuring the mark at small sizes.
context.setFillColor(ink.withAlphaComponent(0.19).cgColor)
for row in 0..<27 {
    for column in 0..<27 {
        let x = CGFloat(column * 40) + (row.isMultiple(of: 2) ? 0 : 20)
        let y = CGFloat(row * 40)
        context.fillEllipse(in: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
    }
}
var burst: [CGPoint] = []
for i in 0..<36 {
    let angle = CGFloat(i) * .pi / 18
    let radius: CGFloat = i.isMultiple(of: 2) ? 730 : 286
    burst.append(CGPoint(x: 530 + cos(angle) * radius, y: 528 + sin(angle) * radius))
}
polygon(burst, color: red)
// Offset cyan printing plate and heavy black balloon outline.
let balloon = [CGPoint(x: 168, y: 792), CGPoint(x: 816, y: 838), CGPoint(x: 867, y: 279),
               CGPoint(x: 394, y: 244), CGPoint(x: 225, y: 111), CGPoint(x: 253, y: 256), CGPoint(x: 129, y: 278)]
polygon(balloon.map { CGPoint(x: $0.x + 25, y: $0.y - 32) }, color: cyan, width: 26)
polygon(balloon, color: .white, width: 27)
// Bespoke condensed C with a slight forward slant, cut to read like a comic masthead.
polygon([CGPoint(x: 736, y: 715), CGPoint(x: 390, y: 715), CGPoint(x: 303, y: 625),
         CGPoint(x: 278, y: 423), CGPoint(x: 356, y: 328), CGPoint(x: 705, y: 328),
         CGPoint(x: 721, y: 457), CGPoint(x: 446, y: 457), CGPoint(x: 431, y: 477),
         CGPoint(x: 441, y: 564), CGPoint(x: 465, y: 586), CGPoint(x: 720, y: 586)], color: red, width: 18)
// Tiny highlight slash gives the letter the punch of printed display lettering.
polygon([CGPoint(x: 396, y: 687), CGPoint(x: 654, y: 687), CGPoint(x: 649, y: 672), CGPoint(x: 389, y: 672)], color: yellow)

let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
guard CommandLine.arguments.count == 2 else {
    fatalError("Pass the output PNG path as the only argument.")
}
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
