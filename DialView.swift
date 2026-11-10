import AppKit

@MainActor
final class DialView: NSView {
    var elapsed: Duration = .zero { didSet { needsDisplay = true } }
    var onDurationChange: ((Int64) -> Void)?
    var allowsEditing = false {
        didSet {
            if !allowsEditing { drag = nil }
            toolTip = allowsEditing ? "Drag a hand to adjust hours, minutes, or seconds. Click elsewhere on the dial to set minutes." : nil
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }
    private enum Hand: CaseIterable {
        case hour, minute, second
        var unitsPerTurn: Double { self == .hour ? 12 : 60 }
        var secondsPerUnit: Int64 { self == .hour ? 3600 : self == .minute ? 60 : 1 }
        var period: Double { unitsPerTurn * Double(secondsPerUnit) }
        var length: CGFloat { self == .hour ? 0.43 : self == .minute ? 0.7 : 0.95 }
    }
    private struct Drag {
        let hand: Hand
        var base: Int64
        var lastAngle: Double
        var accumulatedAngle = 0.0
    }
    private var drag: Drag?
    private var hovering = false
    private var tracking: NSTrackingArea?
    private var center: NSPoint { NSPoint(x: bounds.midX, y: bounds.midY) }
    private var radius: CGFloat { min(bounds.width, bounds.height) / 2 - 12 }
    private var seconds: Double {
        let parts = elapsed.components
        return max(0, Double(parts.seconds) + Double(parts.attoseconds) / 1e18)
    }
    override var mouseDownCanMoveWindow: Bool { !allowsEditing }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    override func resetCursorRects() {
        if allowsEditing { addCursorRect(bounds, cursor: .openHand) }
    }

    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }

    override func mouseDown(with event: NSEvent) {
        guard allowsEditing, radius > 0 else { super.mouseDown(with: event); return }
        let location = convert(event.locationInWindow, from: nil)
        guard hypot(location.x - center.x, location.y - center.y) > 5 else { return }
        let angle = angle(at: location)
        let nearest = Hand.allCases.min { distance(to: $0, from: location) < distance(to: $1, from: location) }
        let grabbedHand = nearest.flatMap { distance(to: $0, from: location) <= 14 ? $0 : nil }
        let hand = grabbedHand ?? .minute
        var base = Int64(ceil(seconds))
        if grabbedHand == nil {
            let minute = Int64((angle / (2 * .pi) * 60).rounded()) % 60
            base = min(359_999, (base / 3600) * 3600 + minute * 60 + base % 60)
            publish(base)
        }
        drag = Drag(hand: hand, base: base, lastAngle: angle)
        NSCursor.closedHand.set()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard allowsEditing, var current = drag else { return }
        let location = convert(event.locationInWindow, from: nil)
        // Ignore the ambiguous angle immediately around the center.
        guard hypot(location.x - center.x, location.y - center.y) > 5 else { return }
        let next = angle(at: location)
        current.accumulatedAngle += Self.angleDelta(from: current.lastAngle, to: next)
        current.lastAngle = next
        let units = Int64((current.accumulatedAngle / (2 * .pi) * current.hand.unitsPerTurn).rounded())
        let proposed = current.base + units * current.hand.secondsPerUnit
        let bounded = min(359_999, max(0, proposed))
        if bounded != proposed {
            current.base = bounded
            current.accumulatedAngle = 0
        }
        drag = current
        publish(bounded)
    }

    override func mouseUp(with event: NSEvent) {
        guard drag != nil else { return }
        drag = nil
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    private func publish(_ duration: Int64) {
        elapsed = .seconds(duration)
        onDurationChange?(duration)
    }

    // Unwrap each pointer movement so crossing 12 carries through rather than resetting.
    static func angleDelta(from previous: Double, to next: Double) -> Double {
        var delta = next - previous
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return delta
    }

    private func angle(at location: NSPoint) -> Double {
        let value = atan2(Double(location.x - center.x), Double(location.y - center.y))
        return value < 0 ? value + 2 * .pi : value
    }

    private func tip(for hand: Hand) -> NSPoint {
        point(center, radius * hand.length, CGFloat(seconds.truncatingRemainder(dividingBy: hand.period) / hand.period) * 2 * .pi)
    }

    private func distance(to hand: Hand, from location: NSPoint) -> CGFloat {
        let tip = tip(for: hand)
        return hypot(tip.x - location.x, tip.y - location.y)
    }

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 12
        guard radius > 0 else { return }
        for tick in 0..<60 {
            let angle = CGFloat(tick) * .pi / 30
            let major = tick % 5 == 0
            let path = NSBezierPath()
            path.move(to: point(center, radius - (major ? 9 : 4), angle))
            path.line(to: point(center, radius, angle))
            path.lineWidth = major ? 1.4 : 0.7
            NSColor.white.withAlphaComponent(major ? 0.8 : 0.3).setStroke()
            path.stroke()
            if major {
                let label = "\(tick == 0 ? 12 : tick / 5)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.75)
                ]
                let size = label.size(withAttributes: attributes)
                let location = point(center, radius - 22, angle)
                label.draw(at: NSPoint(x: location.x - size.width / 2, y: location.y - size.height / 2),
                           withAttributes: attributes)
            }
        }
        let parts = elapsed.components
        let total = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
        drawHand(center, radius * 0.43, CGFloat(total.truncatingRemainder(dividingBy: 43200) / 43200) * .pi * 2,
                 width: 3, color: .white)
        drawHand(center, radius * 0.7, CGFloat(total.truncatingRemainder(dividingBy: 3600) / 3600) * .pi * 2,
                 width: 2, color: .white)
        let seconds = Double(parts.seconds % 60) + Double(parts.attoseconds) / 1e18
        let angle = CGFloat(seconds) * .pi / 30
        let hand = NSBezierPath()
        hand.move(to: point(center, -9, angle))
        hand.line(to: point(center, radius - 5, angle))
        hand.lineWidth = 1.7
        hand.lineCapStyle = .round
        NSColor.systemOrange.setStroke()
        hand.stroke()
        NSColor.systemOrange.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)).fill()
        if allowsEditing && (hovering || drag != nil) {
            for hand in Hand.allCases {
                let location = tip(for: hand)
                let selected = drag?.hand == hand
                let color = hand == .second ? NSColor.systemOrange : NSColor.white
                color.withAlphaComponent(selected ? 0.9 : 0.55).setFill()
                let size: CGFloat = selected ? 5 : 3.5
                NSBezierPath(ovalIn: NSRect(x: location.x - size, y: location.y - size,
                                            width: size * 2, height: size * 2)).fill()
            }
        }
    }

    private func drawHand(_ center: NSPoint, _ length: CGFloat, _ angle: CGFloat, width: CGFloat, color: NSColor) {
        let hand = NSBezierPath()
        hand.move(to: center)
        hand.line(to: point(center, length, angle))
        hand.lineWidth = width
        hand.lineCapStyle = .round
        color.withAlphaComponent(0.9).setStroke()
        hand.stroke()
    }

    private func point(_ center: NSPoint, _ radius: CGFloat, _ angle: CGFloat) -> NSPoint {
        NSPoint(x: center.x + sin(angle) * radius, y: center.y + cos(angle) * radius)
    }
}
