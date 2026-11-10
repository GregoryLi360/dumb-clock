import AppKit

@main
struct PickerTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let editor = DurationFieldEditor(frame: NSRect(x: 0, y: 0, width: 200, height: 40), textContainer: nil)
        editor.string = "00:00:00"
        editor.setSelectedRange(NSRange(location: 0, length: 8))
        editor.insertText("010203", replacementRange: editor.selectedRange())
        assert(editor.string == "01:02:03", "Native editor text: \(editor.string)")
        editor.setSelectedRange(NSRange(location: 0, length: 8))
        editor.deleteBackward(nil)
        assert(editor.string == "00:00:00")
        editor.setSelectedRange(NSRange(location: 2, length: 0))
        assert(editor.selectedRange() == NSRange(location: 3, length: 1))
        editor.moveLeft(nil)
        assert(editor.selectedRange() == NSRange(location: 1, length: 1))
        editor.moveRight(nil)
        assert(editor.selectedRange() == NSRange(location: 3, length: 1))
        editor.insertText("2", replacementRange: NSRange(location: NSNotFound, length: 0))
        assert(editor.string == "00:20:00")
        assert(editor.selectedRange() == NSRange(location: 4, length: 1))
        editor.insertText("5", replacementRange: NSRange(location: NSNotFound, length: 0))
        assert(editor.string == "00:25:00")
        assert(editor.selectedRange() == NSRange(location: 6, length: 1))
        editor.setSelectedRange(NSRange(location: 0, length: 8))
        let selectedPositions = editor.selectedRanges.flatMap { Array($0.rangeValue.location..<NSMaxRange($0.rangeValue)) }
        assert(selectedPositions == DurationMask.positions)
        let cleared = DurationMask.delete("12:34:56", range: NSRange(location: 0, length: 8), backward: true)
        assert(cleared.0 == "00:00:00")
        let back = DurationMask.delete("12:34:56", range: NSRange(location: 6, length: 0), backward: true)
        assert(back.0 == "12:30:56" && back.1 == 4)
        let forward = DurationMask.delete("12:34:56", range: NSRange(location: 2, length: 0), backward: false)
        assert(forward.0 == "12:04:56")
        assert(DurationMask.replace("12:34:56", range: NSRange(location: 0, length: 8), input: "010203").0 == "01:02:03")
        assert(DurationMask.replace("00:00:00", range: NSRange(location: 3, length: 0), input: "25").0 == "00:25:00")
        assert(DurationInput.parse("01:02:03") == 3723)
        assert(DurationInput.parse("1:30") == 90)
        assert(DurationInput.parse("90") == 90)
        assert(DurationInput.parse("00:90:00") == 5400)
        assert(DurationInput.parse("00::05") == 5)
        assert(DurationInput.parse("99:59:59") == 359999)
        assert(DurationInput.parse("100:00:00") == nil)
        assert(DurationInput.parse("-1:00") == nil)
        assert(DurationInput.parse("abc") == nil)
        assert(DurationInput.parse("1:2:3:4") == nil)
        print("Cursor editor checks passed: duration parsing, normalization, bounds and invalid input.")
    }
}
