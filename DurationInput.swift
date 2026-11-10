import AppKit

/// One native editor: real caret, selection, copy/paste and uninterrupted navigation.
@MainActor
final class DurationInput: NSView, NSTextFieldDelegate {
    var onCommit: ((Int64) -> Void)?
    var onActivate: (() -> Void)?
    private let field = DurationField(string: "00:05:00")
    private var editing = false
    private var displayedSeconds: Int64 = 300
    var font = NSFont.monospacedDigitSystemFont(ofSize: 32, weight: .regular) {
        didSet { field.font = font }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.alignment = .center
        field.textColor = .white
        field.font = font
        field.delegate = self
        field.setAccessibilityLabel("Countdown duration")
        field.toolTip = "Edit hours:minutes:seconds. Arrow keys move the cursor; ↑ / ↓ adjusts the current unit."
        addSubview(field)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        field.frame = bounds
    }

    static func parse(_ text: String) -> Int64? {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var total: Int64 = 0
        for part in parts {
            guard part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Int64(part.isEmpty ? "0" : String(part)), number <= 359_999 else { return nil }
            total = total * 60 + number
            guard total <= 359_999 else { return nil }
        }
        return total
    }

    func show(seconds: Int64) {
        displayedSeconds = min(359_999, max(0, seconds))
        guard !editing else { return }
        field.stringValue = Stopwatch.format(seconds: displayedSeconds)
        field.textColor = .white
    }

    func discardEdits() {
        editing = false
        field.textColor = .white
        field.stringValue = Stopwatch.format(seconds: displayedSeconds)
    }

    func controlTextDidBeginEditing(_ notification: Notification) { editing = true }

    func controlTextDidChange(_ notification: Notification) {
        editing = true
        field.textColor = .white
        if field.stringValue.count != 8 {
            let editor = field.currentEditor() as? NSTextView
            let caret = editor?.selectedRange().location ?? 0
            field.stringValue = Stopwatch.format(seconds: Self.parse(field.stringValue) ?? displayedSeconds)
            editor?.string = field.stringValue
            editor?.setSelectedRange(NSRange(location: min(caret, 8), length: 0))
        }
        // Keep Start's enabled state current without replacing text or moving the caret.
        if let value = Self.parse(field.stringValue) {
            displayedSeconds = value
            onCommit?(value)
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if !commit() { discardEdits() }
    }

    @discardableResult
    func commit() -> Bool {
        guard let value = Self.parse(field.stringValue) else {
            field.textColor = .systemOrange
            return false
        }
        let changed = value != displayedSeconds
        displayedSeconds = value
        editing = false
        field.stringValue = Stopwatch.format(seconds: value)
        field.textColor = .white
        if changed { onCommit?(value) }
        return value > 0
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            guard commit() else { NSSound.beep(); return true }
            window?.makeFirstResponder(nil)
            onActivate?()
            return true
        }
        let up = commandSelector == #selector(NSResponder.moveUp(_:))
        let down = commandSelector == #selector(NSResponder.moveDown(_:))
        guard up || down, let value = Self.parse(field.stringValue) else { return false }
        let caret = textView.selectedRange().location
        let prefix = String(field.stringValue.prefix(caret))
        let remainingColons = field.stringValue.filter { $0 == ":" }.count - prefix.filter { $0 == ":" }.count
        let unit: Int64 = remainingColons >= 2 ? 3600 : remainingColons == 1 ? 60 : 1
        let next = min(359_999, max(0, value + (up ? unit : -unit)))
        let formatted = Stopwatch.format(seconds: next)
        field.stringValue = formatted
        textView.string = formatted
        textView.setSelectedRange(NSRange(location: min(caret, formatted.count), length: 0))
        displayedSeconds = next
        onCommit?(next)
        return true
    }
}

/// Fixed-width edits preserve every digit position and both separators.
struct DurationMask {
    static let positions = [0, 1, 3, 4, 6, 7]

    static func replace(_ text: String, range: NSRange, input: String) -> (String, Int) {
        var characters = Array(text.count == 8 ? text : "00:00:00")
        let selected = positions.filter { NSLocationInRange($0, range) }
        for position in selected { characters[position] = "0" }
        var position = min(range.location, 8)
        for digit in input where digit.isASCII && digit.isNumber {
            guard let slot = positions.first(where: { $0 >= position }) else { break }
            characters[slot] = digit
            position = positions.first(where: { $0 > slot }) ?? 8
        }
        return (String(characters), position)
    }

    static func delete(_ text: String, range: NSRange, backward: Bool) -> (String, Int) {
        if range.length > 0 { return replace(text, range: range, input: "") }
        let slot = backward ? positions.last(where: { $0 < range.location })
                            : positions.first(where: { $0 >= range.location })
        guard let slot else { return (text, range.location) }
        let result = replace(text, range: NSRange(location: slot, length: 1), input: "")
        return (result.0, backward ? slot : (positions.first(where: { $0 > slot }) ?? 8))
    }
}

@MainActor
final class DurationField: NSTextField {
    let durationEditor = DurationFieldEditor(frame: .zero, textContainer: nil)
}

@MainActor
final class DurationFieldEditor: NSTextView {
    private let ownedStorage: NSTextStorage?
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        if let container {
            ownedStorage = nil
            super.init(frame: frameRect, textContainer: container)
        } else {
            let storage = NSTextStorage()
            let layout = NSLayoutManager()
            let container = NSTextContainer(containerSize: NSSize(width: 1000, height: 1000))
            storage.addLayoutManager(layout)
            layout.addTextContainer(container)
            ownedStorage = storage
            super.init(frame: frameRect, textContainer: container)
        }
        isFieldEditor = true
        isRichText = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        selectedTextAttributes = [.backgroundColor: NSColor.systemOrange.withAlphaComponent(0.85),
                                  .foregroundColor: NSColor.black]
    }

    required init?(coder: NSCoder) { nil }

    private func digitRanges(_ range: NSRange) -> [NSValue] {
        guard string.count == 8 else { return [NSValue(range: range)] }
        let slots = range.length > 0 ? DurationMask.positions.filter { NSLocationInRange($0, range) } : []
        let positions = slots.isEmpty ? [DurationMask.positions.first(where: { $0 >= min(7, range.location) }) ?? 7] : slots
        return positions.map { NSValue(range: NSRange(location: $0, length: 1)) }
    }

    override func setSelectedRange(_ charRange: NSRange) {
        super.setSelectedRanges(digitRanges(charRange), affinity: .downstream, stillSelecting: false)
    }

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(digitRanges(charRange), affinity: affinity, stillSelecting: stillSelecting)
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges.flatMap { digitRanges($0.rangeValue) }, affinity: affinity, stillSelecting: stillSelecting)
    }

    private var editRange: NSRange {
        let ranges = selectedRanges.map { $0.rangeValue }
        guard let first = ranges.first, let last = ranges.last else { return selectedRange() }
        return NSRange(location: first.location, length: NSMaxRange(last) - first.location)
    }

    override func moveLeft(_ sender: Any?) {
        let position = DurationMask.positions.last(where: { $0 < editRange.location }) ?? 0
        setSelectedRange(NSRange(location: position, length: 1))
    }

    override func moveRight(_ sender: Any?) {
        let position = DurationMask.positions.first(where: { $0 >= NSMaxRange(editRange) }) ?? 7
        setSelectedRange(NSRange(location: position, length: 1))
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        let input = (insertString as? String) ?? (insertString as? NSAttributedString)?.string ?? ""
        let range = replacementRange.location == NSNotFound || selectedRanges.count > 1 ? editRange : replacementRange
        guard input.contains(where: { $0.isASCII && $0.isNumber }) else { return }
        if input.contains(":"), let value = DurationInput.parse(input) {
            apply((Stopwatch.format(seconds: value), 8))
        } else {
            apply(DurationMask.replace(string, range: range, input: input))
        }
    }

    override func deleteBackward(_ sender: Any?) {
        let range = editRange
        let value = DurationMask.replace(string, range: range, input: "").0
        apply((value, DurationMask.positions.last(where: { $0 < range.location }) ?? 0))
    }

    override func deleteForward(_ sender: Any?) {
        let range = editRange
        let value = DurationMask.replace(string, range: range, input: "").0
        apply((value, DurationMask.positions.first(where: { $0 >= NSMaxRange(range) }) ?? 7))
    }

    override func deleteWordBackward(_ sender: Any?) {
        let caret = selectedRange().location
        let start = caret > 6 ? 6 : caret > 3 ? 3 : 0
        apply(DurationMask.replace(string, range: NSRange(location: start, length: caret - start), input: ""))
    }

    override func deleteToBeginningOfLine(_ sender: Any?) {
        apply(DurationMask.replace(string, range: NSRange(location: 0, length: selectedRange().location), input: ""))
    }

    override func deleteToEndOfLine(_ sender: Any?) {
        let caret = min(8, selectedRange().location)
        apply(DurationMask.replace(string, range: NSRange(location: caret, length: 8 - caret), input: ""))
    }

    override func cut(_ sender: Any?) {
        guard selectedRange().length > 0 else { return }
        copy(sender)
        deleteBackward(sender)
    }

    override func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        insertText(text, replacementRange: selectedRange())
    }

    private func apply(_ result: (String, Int)) {
        super.insertText(result.0, replacementRange: NSRange(location: 0, length: (string as NSString).length))
        setSelectedRange(NSRange(location: min(8, result.1), length: 0))
    }
}
