import AppKit

func rounded(_ rect: NSRect, _ radius: CGFloat, _ color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func stroke(_ from: NSPoint, _ to: NSPoint, width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: from); path.line(to: to)
    path.lineWidth = width; path.lineCapStyle = .round
    color.setStroke(); path.stroke()
}
func save(_ path: String, size: NSSize, drawing: () -> Void) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawing()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
let cream = NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.90, alpha: 1)
let orange = NSColor(calibratedRed: 1, green: 0.48, blue: 0.19, alpha: 1)
try save("assets/AppIcon.png", size: NSSize(width: 1024, height: 1024)) {
    let rect = NSRect(x: 28, y: 28, width: 968, height: 968)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
    NSGradient(starting: NSColor(calibratedWhite: 0.20, alpha: 1), ending: NSColor(calibratedWhite: 0.075, alpha: 1))!
        .draw(in: shape, angle: -90)
    rounded(NSRect(x: 459, y: 813, width: 106, height: 52), 18, cream)
    rounded(NSRect(x: 491, y: 760, width: 42, height: 70), 14, cream)
    let ring = NSBezierPath(ovalIn: NSRect(x: 226, y: 196, width: 572, height: 572))
    ring.lineWidth = 32; cream.setStroke(); ring.stroke()
    let center = NSPoint(x: 512, y: 482)
    for index in 0..<12 {
        let angle = CGFloat(index) * .pi / 6
        stroke(NSPoint(x: center.x + sin(angle) * 236, y: center.y + cos(angle) * 236),
               NSPoint(x: center.x + sin(angle) * 250, y: center.y + cos(angle) * 250),
               width: 9, color: cream.withAlphaComponent(0.4))
    }
    stroke(center, NSPoint(x: 512, y: 662), width: 24, color: cream)
    stroke(NSPoint(x: 477, y: 458), NSPoint(x: 678, y: 598), width: 27, color: orange)
    orange.setFill(); NSBezierPath(ovalIn: NSRect(x: 489, y: 459, width: 46, height: 46)).fill()
}
try save("assets/installer-background.png", size: NSSize(width: 640, height: 400)) {
    NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.92, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 640, height: 400).fill()
    let title = "stopwatch" as NSString
    let titleStyle: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 29, weight: .semibold), .foregroundColor: NSColor(calibratedWhite: 0.13, alpha: 1)]
    title.draw(at: NSPoint(x: (640 - title.size(withAttributes: titleStyle).width) / 2, y: 326), withAttributes: titleStyle)
    let subtitle = "Drag to Applications. That's it." as NSString
    let subtitleStyle: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor(calibratedWhite: 0.35, alpha: 1)]
    subtitle.draw(at: NSPoint(x: (640 - subtitle.size(withAttributes: subtitleStyle).width) / 2, y: 298), withAttributes: subtitleStyle)
    stroke(NSPoint(x: 296, y: 200), NSPoint(x: 344, y: 200), width: 3, color: orange)
    stroke(NSPoint(x: 332, y: 211), NSPoint(x: 344, y: 200), width: 3, color: orange)
    stroke(NSPoint(x: 332, y: 189), NSPoint(x: 344, y: 200), width: 3, color: orange)
    let footer = "A little time. Nothing else." as NSString
    let footerStyle: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(calibratedWhite: 0.45, alpha: 1)]
    footer.draw(at: NSPoint(x: (640 - footer.size(withAttributes: footerStyle).width) / 2, y: 65), withAttributes: footerStyle)
}
