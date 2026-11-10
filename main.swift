import AppKit

@MainActor
final class PinButton: NSButton {
    var pinned = true { didSet { updateIcon() } }
    private var hovering = false
    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { hovering = true; updateIcon() }
    override func mouseExited(with event: NSEvent) { hovering = false; updateIcon() }

    private func updateIcon() {
        let name = pinned ? (hovering ? "pin.slash.fill" : "pin.fill") : "pin"
        let label = pinned ? "Unpin window" : "Pin on top"
        image = NSImage(systemSymbolName: name, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        setAccessibilityLabel(label)
        contentTintColor = NSColor.white.withAlphaComponent(pinned || hovering ? 1 : 0.45)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.backgroundColor = NSColor.white.withAlphaComponent(!pinned && hovering ? 0.12 : 0).cgColor
    }
}

@MainActor
final class StopwatchWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class StopwatchView: NSView {
    private var stopwatch = Stopwatch()
    private var countdown = Countdown(duration: Int64(max(0, UserDefaults.standard.object(forKey: "duration") as? Int ?? 300)))
    private var ticker: Timer?
    private var timerMode = UserDefaults.standard.bool(forKey: "timerMode")
    private var analog = UserDefaults.standard.bool(forKey: "analog")
    private var ringing = false
    private var pinned = UserDefaults.standard.object(forKey: "pinned") as? Bool ?? true
    private let alarm = NSSound(named: "Glass")
    private let digits = NSTextField(labelWithString: "00:00:00")
    private let dial = DialView()
    private let start = NSButton()
    private let reset = NSButton()
    private let pin = PinButton()
    private let close = NSButton()
    private let viewToggle = NSButton()
    private let durationInput = DurationInput()
    private let stopwatchMode = NSButton(title: "Stopwatch", target: nil, action: nil)
    private let countdownMode = NSButton(title: "Timer", target: nil, action: nil)

    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        // True transparency, without a material's opaque fallback or a painted border.
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.42).cgColor
        digits.alignment = .center
        digits.textColor = .white
        digits.setAccessibilityLabel("Elapsed time")
        for button in [start, reset, pin, close, viewToggle, stopwatchMode, countdownMode] {
            button.isBordered = false
            button.target = self
            button.contentTintColor = NSColor.white.withAlphaComponent(0.7)
            button.focusRingType = .none
            button.font = .systemFont(ofSize: 11, weight: .medium)
            addSubview(button)
        }
        start.action = #selector(toggle)
        start.keyEquivalent = " "
        start.keyEquivalentModifierMask = []
        start.toolTip = "Start / pause (Space)"
        start.contentTintColor = .white
        reset.action = #selector(clear)
        reset.keyEquivalent = "r"
        reset.keyEquivalentModifierMask = []
        reset.toolTip = "Reset and stop (R)"
        symbol(reset, "arrow.counterclockwise", "Reset")
        pin.action = #selector(togglePin)
        close.action = #selector(hideWindow)
        close.toolTip = "Hide — reopen from the menu bar"
        symbol(close, "xmark", "Hide stopwatch", size: 9)
        viewToggle.action = #selector(changeView)
        stopwatchMode.action = #selector(selectStopwatch)
        countdownMode.action = #selector(selectCountdown)
        addSubview(dial)
        addSubview(digits)
        addSubview(durationInput)
        durationInput.onCommit = { [weak self] duration in
            guard let self else { return }
            self.countdown = Countdown(duration: duration)
            UserDefaults.standard.set(Int(duration), forKey: "duration")
            self.refresh()
        }
        durationInput.onActivate = { [weak self] in self?.toggle() }
        dial.onDurationChange = { [weak self] duration in
            guard let self else { return }
            self.durationInput.discardEdits()
            self.window?.makeFirstResponder(nil)
            self.countdown = Countdown(duration: duration)
            UserDefaults.standard.set(Int(duration), forKey: "duration")
            self.refresh()
        }
        alarm?.loops = true
        refresh()
    }

    required init?(coder: NSCoder) { nil }
    override var mouseDownCanMoveWindow: Bool { true }
    private var showsDial: Bool { analog }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyPin()
    }

    override func layout() {
        super.layout()
        let top = bounds.height - 27
        close.frame = NSRect(x: 5, y: top, width: 22, height: 20)
        pin.frame = NSRect(x: bounds.width - 27, y: top, width: 22, height: 22)
        stopwatchMode.frame = NSRect(x: bounds.midX - 74, y: top, width: 87, height: 20)
        countdownMode.frame = NSRect(x: bounds.midX + 17, y: top, width: 55, height: 20)
        digits.frame = NSRect(x: 14, y: 35, width: bounds.width - 28,
                              height: showsDial ? 22 : bounds.height - 66)
        dial.frame = NSRect(x: 14, y: 62, width: bounds.width - 28, height: bounds.height - 94)
        let first = bounds.midX - 61
        let spacing: CGFloat = 47
        reset.frame = NSRect(x: first, y: 6, width: 28, height: 25)
        start.frame = NSRect(x: first + spacing, y: 6, width: 28, height: 25)
        viewToggle.frame = NSRect(x: first + spacing * 2, y: 6, width: 28, height: 25)
        durationInput.frame = digits.frame
        fitDigits()
    }

    private func symbol(_ button: NSButton, _ name: String, _ label: String, size: CGFloat = 13) {
        button.title = ""
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .medium))
        button.setAccessibilityLabel(label)
    }

    private func fitDigits() {
        let widthPerCharacter = (bounds.width - 28) / CGFloat(max(1, digits.stringValue.count))
        let size: CGFloat = showsDial ? 16 : min(56, max(16, min(widthPerCharacter / 0.63, bounds.height - 70)))
        digits.font = .monospacedDigitSystemFont(ofSize: size, weight: .regular)
        durationInput.font = .monospacedDigitSystemFont(ofSize: size, weight: .regular)
    }

    @objc private func toggle() {
        if timerMode && !ringing && countdown.clock.started == nil {
            guard durationInput.commit() else { NSSound.beep(); return }
            window?.makeFirstResponder(nil)
        }
        let now = ContinuousClock.now
        if ringing {
            alarm?.stop()
            ringing = false
            countdown = Countdown(duration: countdown.duration)
            updateTicker()
            refresh()
            return
        }
        if timerMode { countdown = countdown.toggled(at: now) }
        else { stopwatch = stopwatch.toggled(at: now) }
        updateTicker()
        refresh()
    }

    @objc private func clear() {
        if timerMode {
            durationInput.discardEdits()
            window?.makeFirstResponder(nil)
            alarm?.stop()
            ringing = false
            countdown = Countdown(duration: countdown.duration)
        } else { stopwatch = Stopwatch() }
        updateTicker()
        refresh()
    }

    private func updateTicker() {
        ticker?.invalidate()
        ticker = nil
        guard stopwatch.started != nil || countdown.clock.started != nil else { return }
        let tick = Timer(timeInterval: showsDial ? 1.0 / 30 : 0.1, target: self,
                         selector: #selector(refresh), userInfo: nil, repeats: true)
        tick.tolerance = showsDial ? 0.005 : 0.02
        RunLoop.main.add(tick, forMode: .common)
        ticker = tick
    }

    @objc private func selectStopwatch() {
        timerMode = false
        UserDefaults.standard.set(false, forKey: "timerMode")
        updateView()
    }
    @objc private func selectCountdown() {
        timerMode = true
        UserDefaults.standard.set(true, forKey: "timerMode")
        updateView()
    }

    @objc private func changeView() {
        analog.toggle()
        UserDefaults.standard.set(analog, forKey: "analog")
        updateView(resize: true)
    }

    private func updateView(resize: Bool = false) {
        window?.makeFirstResponder(nil)
        if resize, let window {
            let minimum = NSSize(width: 210, height: showsDial ? 230 : 108)
            window.contentMinSize = minimum
            var frame = window.frame
            let height: CGFloat = showsDial ? max(250, frame.height) : 114
            frame.origin.y += frame.height - height
            frame.size.height = height
            window.setFrame(frame, display: true)
        }
        needsLayout = true
        updateTicker()
        refresh()
    }

    override func keyDown(with event: NSEvent) {
        if [36, 76, 49].contains(event.keyCode), start.isEnabled { toggle() }
        else { super.keyDown(with: event) }
    }

    @objc private func togglePin() {
        pinned.toggle()
        UserDefaults.standard.set(pinned, forKey: "pinned")
        applyPin()
        // Keep the clicked window in front now; normal stacking takes over on the next app switch.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func applyPin() {
        window?.level = pinned ? .floating : .normal
        window?.collectionBehavior = pinned ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
        pin.pinned = pinned
        pin.toolTip = pinned ? "Pinned — click for normal window behavior" : "Unpinned — click to stay on top"
    }

    @objc private func hideWindow() { window?.orderOut(nil) }

    @objc private func refresh() {
        let now = ContinuousClock.now
        if countdown.clock.started != nil && countdown.finished(at: now) {
            countdown = Countdown(duration: countdown.duration,
                                  clock: Stopwatch(accumulated: .seconds(countdown.duration)))
            ringing = true
            timerMode = true
            updateView()
            if alarm?.play() != true { NSSound.beep() }
            window?.orderFrontRegardless()
            updateTicker()
        }
        dial.isHidden = !showsDial
        let editingTimer = timerMode && countdown.clock.started == nil && !ringing
        dial.allowsEditing = editingTimer
        durationInput.isHidden = !editingTimer
        digits.isHidden = editingTimer
        if editingTimer { durationInput.show(seconds: countdown.remaining(at: now)) }
        dial.elapsed = timerMode ? max(.zero, .seconds(countdown.duration) - countdown.clock.elapsed(at: now))
                                 : stopwatch.elapsed(at: now)
        digits.stringValue = timerMode ? Stopwatch.format(seconds: countdown.remaining(at: now)) : stopwatch.text(at: now)
        digits.textColor = ringing && timerMode ? .systemOrange : .white
        digits.setAccessibilityLabel(timerMode ? "Time remaining" : "Elapsed time")
        let running = timerMode ? countdown.clock.started != nil : stopwatch.started != nil
        start.isEnabled = ringing || !timerMode || countdown.duration > 0
        reset.isEnabled = ringing || (timerMode ? countdown.clock.elapsed(at: now) > .zero : stopwatch.elapsed(at: now) > .zero)
        symbol(start, ringing ? "stop.fill" : running ? "pause.fill" : "play.fill",
               ringing ? "Stop alarm" : running ? "Pause" : "Start")
        start.toolTip = ringing ? "Stop alarm (Space)" : "Start / pause (Space)"
        start.contentTintColor = ringing || running ? .systemOrange : .systemGreen
        symbol(viewToggle, showsDial ? "number" : "clock", showsDial ? "Digital view" : "Analog view")
        viewToggle.toolTip = showsDial ? "Digital view" : "Analog dial"
        stopwatchMode.contentTintColor = NSColor.white.withAlphaComponent(timerMode ? 0.45 : 1)
        countdownMode.contentTintColor = NSColor.white.withAlphaComponent(timerMode ? 1 : 0.45)
        fitDigits()
    }


}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: StopwatchWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let analog = UserDefaults.standard.bool(forKey: "analog")
        let window = StopwatchWindow(contentRect: NSRect(x: 0, y: 0, width: 240, height: analog ? 250 : 114),
                                     styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        window.title = "stopwatch"
        window.delegate = self
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.contentMinSize = NSSize(width: 210, height: analog ? 230 : 108)
        window.contentMaxSize = NSSize(width: 600, height: 500)
        window.contentView = StopwatchView(frame: NSRect(x: 0, y: 0, width: 240, height: 114))
        window.isReleasedWhenClosed = false
        if let screen = NSScreen.main {
            let area = screen.visibleFrame
            window.setFrameTopLeftPoint(NSPoint(x: area.maxX - 260, y: area.maxY - 20))
        }
        window.setFrameAutosaveName("StopwatchWindowV2")
        self.window = window
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "stopwatch")
        item.button?.toolTip = "stopwatch"
        let menu = NSMenu()
        let show = menu.addItem(withTitle: "Show stopwatch", action: #selector(showWindow), keyEquivalent: "")
        show.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit stopwatch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit stopwatch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appEntry = NSMenuItem(title: "stopwatch", action: nil, keyEquivalent: "")
        appEntry.submenu = appMenu
        mainMenu.addItem(appEntry)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editEntry = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editEntry.submenu = editMenu
        mainMenu.addItem(editEntry)
        NSApp.mainMenu = mainMenu
        showWindow()
    }

    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        (client as? DurationField)?.durationEditor
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
}

// Carry forward preferences from the development build without changing that app's data.
if Bundle.main.bundleIdentifier == "com.gregoryli.stopwatch",
   UserDefaults.standard.persistentDomain(forName: "com.gregoryli.stopwatch") == nil,
   let legacy = UserDefaults.standard.persistentDomain(forName: "local.gregoryli.stopwatch") {
    UserDefaults.standard.setPersistentDomain(legacy, forName: "com.gregoryli.stopwatch")
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.setActivationPolicy(.accessory)
application.delegate = delegate
application.run()
