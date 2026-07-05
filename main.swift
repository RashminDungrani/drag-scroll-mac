// ─────────────────────────────────────────────────────────────
// DragScroll — Lightweight Button 5 Drag-to-Scroll for macOS
// ─────────────────────────────────────────────────────────────
// Hold mouse button 5, drag to scroll. Pixel-precise, smooth,
// with momentum — like Mac Mouse Fix's Click & Drag feature.
// ─────────────────────────────────────────────────────────────

import Cocoa
import CoreGraphics

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Configuration
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct ScrollConfig {
    /// Read/write to UserDefaults for persistence
    private let defaults = UserDefaults.standard

    var targetButton: Int64 {
        get {
            let val = defaults.integer(forKey: "button")
            return val == 0 ? 4 : Int64(val) // Default to button 5 (index 4)
        }
        set { defaults.set(Int(newValue), forKey: "button") }
    }

    var scrollSpeed: CGFloat {
        get {
            let val = defaults.double(forKey: "speed")
            return val == 0 ? 4.0 : CGFloat(val)
        }
        set { defaults.set(Double(newValue), forKey: "speed") }
    }

    var smoothingFactor: CGFloat {
        get {
            let val = defaults.double(forKey: "smoothness")
            return val == 0 ? 0.45 : CGFloat(val)
        }
        set { defaults.set(Double(newValue), forKey: "smoothness") }
    }

    var reverseDirection: Bool {
        get { defaults.bool(forKey: "reverse") }
        set { defaults.set(newValue, forKey: "reverse") }
    }

    // Advanced tuning (internal constants)
    let accelerationExponent: CGFloat = 1.15
    let momentumDecay: CGFloat = 0.935
    let momentumThreshold: CGFloat = 0.4
    let momentumInterval: TimeInterval = 1.0 / 120.0
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Event Tap Callback (C-convention free function)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Global C-convention callback required by CGEvent.tapCreate.
/// Forwards events to the DragScrollController via the userInfo pointer.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }
    let controller = Unmanaged<DragScrollController>.fromOpaque(refcon)
        .takeUnretainedValue()
    return controller.handleEvent(proxy: proxy, type: type, event: event)
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - DragScrollController
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final class DragScrollController: NSObject {

    // ── Configuration ──────────────────────────────────────
    private var config = ScrollConfig()

    // ── Event tap ──────────────────────────────────────────
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // ── Scroll state ───────────────────────────────────────
    private var isScrolling = false
    private var hasSentFirstDelta = false

    // ── Smoothing state ────────────────────────────────────
    private var smoothedDX: CGFloat = 0
    private var smoothedDY: CGFloat = 0

    // ── Velocity buffer for momentum ───────────────────────
    private var recentDeltas: [(dx: CGFloat, dy: CGFloat)] = []
    private let velocityBufferSize = 5

    // ── Momentum ───────────────────────────────────────────
    private var momentumVX: CGFloat = 0
    private var momentumVY: CGFloat = 0
    private var momentumTimer: DispatchSourceTimer?
    private var isMomentumFirstTick = false

    // ── Status bar ─────────────────────────────────────────
    private var statusItem: NSStatusItem!

    // ────────────────────────────────────────────────────────
    // MARK: Public API
    // ────────────────────────────────────────────────────────

    func start() {
        registerCleanup()
        setupStatusBar()
        setupEventTap()
    }

    // ────────────────────────────────────────────────────────
    // MARK: Cleanup — restore cursor on any exit
    // ────────────────────────────────────────────────────────

    private func registerCleanup() {
        atexit {
            CGAssociateMouseAndMouseCursorPosition(1)
            CGDisplayShowCursor(CGMainDisplayID())
        }
    }

    // ────────────────────────────────────────────────────────
    // MARK: Status Bar
    // ────────────────────────────────────────────────────────

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use a scroll-like symbol
            button.title = "⇕"
            button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        }

        let menu = NSMenu()

        // ── Title ──
        let titleItem = NSMenuItem(
            title: "DragScroll — Active",
            action: nil, keyEquivalent: ""
        )
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let infoItem = NSMenuItem(
            title: "Hold Button 5 + Drag to Scroll",
            action: nil, keyEquivalent: ""
        )
        infoItem.isEnabled = false
        menu.addItem(infoItem)

        menu.addItem(NSMenuItem.separator())

        // ── Speed submenu ──
        let speedMenu = NSMenu()
        let speeds: [(String, CGFloat)] = [
            ("Slow (1.5×)", 1.5),
            ("Medium (2.5×)", 2.5),
            ("Fast (4.0×)", 4.0),
            ("Very Fast (6.0×)", 6.0),
        ]
        for (name, speed) in speeds {
            let item = NSMenuItem(
                title: name,
                action: #selector(setSpeed(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = speed as NSNumber
            item.state = abs(speed - config.scrollSpeed) < 0.01 ? .on : .off
            speedMenu.addItem(item)
        }
        let speedItem = NSMenuItem(
            title: "Scroll Speed",
            action: nil, keyEquivalent: ""
        )
        speedItem.submenu = speedMenu
        menu.addItem(speedItem)

        // ── Smoothness submenu ──
        let smoothMenu = NSMenu()
        let smoothLevels: [(String, CGFloat)] = [
            ("Snappy (0.6)", 0.6),
            ("Balanced (0.45)", 0.45),
            ("Smooth (0.3)", 0.3),
            ("Ultra Smooth (0.2)", 0.2),
        ]
        for (name, factor) in smoothLevels {
            let item = NSMenuItem(
                title: name,
                action: #selector(setSmoothness(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = factor as NSNumber
            item.state = abs(factor - config.smoothingFactor) < 0.01 ? .on : .off
            smoothMenu.addItem(item)
        }
        let smoothItem = NSMenuItem(
            title: "Smoothness",
            action: nil, keyEquivalent: ""
        )
        smoothItem.submenu = smoothMenu
        menu.addItem(smoothItem)

        menu.addItem(NSMenuItem.separator())

        // ── Reverse direction toggle ──
        let reverseItem = NSMenuItem(
            title: "Reverse Scroll Direction",
            action: #selector(toggleReverse(_:)),
            keyEquivalent: ""
        )
        reverseItem.target = self
        reverseItem.state = config.reverseDirection ? .on : .off
        menu.addItem(reverseItem)

        menu.addItem(NSMenuItem.separator())

        // ── Quit ──
        let quitItem = NSMenuItem(
            title: "Quit DragScroll",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func setSpeed(_ sender: NSMenuItem) {
        guard let speed = sender.representedObject as? NSNumber else { return }
        config.scrollSpeed = CGFloat(speed.doubleValue)
        if let menu = sender.menu {
            for item in menu.items { item.state = .off }
        }
        sender.state = .on
    }

    @objc private func setSmoothness(_ sender: NSMenuItem) {
        guard let factor = sender.representedObject as? NSNumber else { return }
        config.smoothingFactor = CGFloat(factor.doubleValue)
        if let menu = sender.menu {
            for item in menu.items { item.state = .off }
        }
        sender.state = .on
    }

    @objc private func toggleReverse(_ sender: NSMenuItem) {
        config.reverseDirection.toggle()
        sender.state = config.reverseDirection ? .on : .off
    }

    @objc private func quit() {
        // Ensure cursor is restored
        CGAssociateMouseAndMouseCursorPosition(1)
        CGDisplayShowCursor(CGMainDisplayID())
        NSApplication.shared.terminate(nil)
    }

    // ────────────────────────────────────────────────────────
    // MARK: Event Tap Setup
    // ────────────────────────────────────────────────────────

    private func setupEventTap() {
        let eventMask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            showAccessibilityAlert()
            return
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            DragScroll needs Accessibility access to intercept mouse button events.

            Please go to:
            System Settings → Privacy & Security → Accessibility

            Then add and enable DragScroll.
            """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            ) {
                NSWorkspace.shared.open(url)
            }
        }
        NSApplication.shared.terminate(nil)
    }

    // ────────────────────────────────────────────────────────
    // MARK: Event Handling
    // ────────────────────────────────────────────────────────

    func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {

        // Re-enable tap if the system disabled it (happens under heavy load)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let button = event.getIntegerValueField(.mouseEventButtonNumber)

        switch type {

        // ── Target button pressed ──────────────────────────────
        case .otherMouseDown where button == config.targetButton:
            enterScrollMode()
            return nil   // suppress the click

        // ── Target button released ─────────────────────────────
        case .otherMouseUp where button == config.targetButton:
            exitScrollMode()
            return nil   // suppress the release

        // ── Mouse movement while scrolling ─────────────────
        case .otherMouseDragged, .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            if isScrolling {
                let dx = CGFloat(event.getDoubleValueField(.mouseEventDeltaX))
                let dy = CGFloat(event.getDoubleValueField(.mouseEventDeltaY))
                processScrollDelta(dx: dx, dy: dy)
                return nil   // suppress cursor movement
            }

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    // ────────────────────────────────────────────────────────
    // MARK: Scroll Mode Enter / Exit
    // ────────────────────────────────────────────────────────

    private func enterScrollMode() {
        isScrolling = true
        hasSentFirstDelta = false

        // Stop any active momentum
        stopMomentum()

        // Reset smoothing state
        smoothedDX = 0
        smoothedDY = 0
        recentDeltas.removeAll()

        // Freeze & hide cursor (mouse still generates deltas)
        CGAssociateMouseAndMouseCursorPosition(0)
        CGDisplayHideCursor(CGMainDisplayID())
    }

    private func exitScrollMode() {
        guard isScrolling else { return }
        isScrolling = false

        // Restore cursor
        CGAssociateMouseAndMouseCursorPosition(1)
        CGDisplayShowCursor(CGMainDisplayID())

        // Kick off momentum
        startMomentum()
    }

    // ────────────────────────────────────────────────────────
    // MARK: Scroll Delta Processing
    // ────────────────────────────────────────────────────────

    private func processScrollDelta(dx: CGFloat, dy: CGFloat) {
        // 1. Apply acceleration curve
        let accDX = applyAcceleration(dx)
        let accDY = applyAcceleration(dy)

        // 2. Exponential smoothing
        let a = config.smoothingFactor
        let sign: CGFloat = config.reverseDirection ? 1.0 : -1.0

        if !hasSentFirstDelta {
            // Seed the smoother so the first frame isn't zero
            smoothedDX = accDX
            smoothedDY = accDY
            hasSentFirstDelta = true
            
            // Critical: Continuous scrolling MUST begin with a .began phase, 
            // otherwise macOS and apps (like Chrome/Safari) will completely ignore the events.
            postScrollEvent(deltaX: 0, deltaY: 0, phase: .began)
        } else {
            smoothedDX = a * accDX + (1 - a) * smoothedDX
            smoothedDY = a * accDY + (1 - a) * smoothedDY
        }

        // 3. Track recent deltas for momentum calculation
        recentDeltas.append((dx: smoothedDX, dy: smoothedDY))
        if recentDeltas.count > velocityBufferSize {
            recentDeltas.removeFirst()
        }

        // 4. Direction: "grab & drag" means drag-down → content-down
        postScrollEvent(
            deltaX: smoothedDX * sign,
            deltaY: smoothedDY * sign,
            phase: .changed
        )
    }

    /// Non-linear acceleration: slow movements stay precise, fast ones get amplified.
    private func applyAcceleration(_ delta: CGFloat) -> CGFloat {
        let magnitude = abs(delta)
        let direction: CGFloat = delta >= 0 ? 1.0 : -1.0
        let accelerated = pow(magnitude, config.accelerationExponent) * config.scrollSpeed
        return direction * accelerated
    }

    // ────────────────────────────────────────────────────────
    // MARK: Scroll Event Posting
    // ────────────────────────────────────────────────────────

    private enum GesturePhase {
        case began, changed, ended, momentum
    }

    private func postScrollEvent(deltaX: CGFloat, deltaY: CGFloat, phase: GesturePhase) {
        // Create a pixel-precise scroll event (2 axes: vertical + horizontal)
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(round(deltaY)),
            wheel2: Int32(round(deltaX)),
            wheel3: 0
        ) else { return }

        // Mark as continuous (trackpad-like) for native smooth-scroll support
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)

        // Set sub-pixel precision via PointDelta fields
        event.setDoubleValueField(
            CGEventField(rawValue: 96)!, // scrollWheelEventPointDeltaAxis1
            value: Double(deltaY)
        )
        event.setDoubleValueField(
            CGEventField(rawValue: 97)!, // scrollWheelEventPointDeltaAxis2
            value: Double(deltaX)
        )

        // Set gesture phase for apps that support it (Safari, Chrome, etc.)
        switch phase {
        case .began:
            event.setIntegerValueField(
                CGEventField(rawValue: 99)!, // scrollWheelEventScrollPhase
                value: 1  // kCGScrollPhaseBegan
            )
            event.setIntegerValueField(
                CGEventField(rawValue: 123)!, // scrollWheelEventMomentumPhase
                value: 0  // none
            )
        case .changed:
            event.setIntegerValueField(
                CGEventField(rawValue: 99)!,
                value: 2  // kCGScrollPhaseChanged
            )
            event.setIntegerValueField(
                CGEventField(rawValue: 123)!,
                value: 0
            )
        case .ended:
            event.setIntegerValueField(
                CGEventField(rawValue: 99)!,
                value: 4  // kCGScrollPhaseEnded
            )
            event.setIntegerValueField(
                CGEventField(rawValue: 123)!,
                value: 0
            )
        case .momentum:
            event.setIntegerValueField(
                CGEventField(rawValue: 99)!,
                value: 0  // none
            )
            event.setIntegerValueField(
                CGEventField(rawValue: 123)!,
                value: 2  // kCGMomentumScrollPhaseContinue
            )
        }

        event.post(tap: .cghidEventTap)
    }

    // ────────────────────────────────────────────────────────
    // MARK: Momentum Scrolling
    // ────────────────────────────────────────────────────────

    private func startMomentum() {
        guard !recentDeltas.isEmpty else { return }

        // Average recent deltas for a stable initial velocity
        let avgDX = recentDeltas.map(\.dx).reduce(0, +) / CGFloat(recentDeltas.count)
        let avgDY = recentDeltas.map(\.dy).reduce(0, +) / CGFloat(recentDeltas.count)

        let sign: CGFloat = config.reverseDirection ? 1.0 : -1.0
        momentumVX = avgDX * sign
        momentumVY = avgDY * sign

        // Don't start if velocity is negligible
        guard abs(momentumVX) > config.momentumThreshold ||
              abs(momentumVY) > config.momentumThreshold else {
            // Send a clean "ended" phase
            postScrollEvent(deltaX: 0, deltaY: 0, phase: .ended)
            return
        }

        // Send scroll-ended then begin momentum
        postScrollEvent(deltaX: 0, deltaY: 0, phase: .ended)

        isMomentumFirstTick = true

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(
            deadline: .now() + config.momentumInterval,
            repeating: config.momentumInterval
        )
        timer.setEventHandler { [weak self] in
            self?.momentumTick()
        }
        timer.resume()
        momentumTimer = timer
    }

    private func momentumTick() {
        // Apply decay
        momentumVX *= config.momentumDecay
        momentumVY *= config.momentumDecay

        // Check if we should stop
        if abs(momentumVX) < config.momentumThreshold &&
           abs(momentumVY) < config.momentumThreshold {
            stopMomentum()
            return
        }

        postScrollEvent(
            deltaX: momentumVX,
            deltaY: momentumVY,
            phase: .momentum
        )
    }

    private func stopMomentum() {
        momentumTimer?.cancel()
        momentumTimer = nil
        momentumVX = 0
        momentumVY = 0

        // Send momentum end event (delta 0)
        if let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0, wheel2: 0, wheel3: 0
        ) {
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            event.setIntegerValueField(
                CGEventField(rawValue: 99)!, value: 0
            )
            event.setIntegerValueField(
                CGEventField(rawValue: 123)!, value: 3  // kCGMomentumScrollPhaseEnd
            )
            event.post(tap: .cghidEventTap)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - App Delegate
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = DragScrollController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Safety net: always restore cursor
        CGAssociateMouseAndMouseCursorPosition(1)
        CGDisplayShowCursor(CGMainDisplayID())
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Main Entry Point
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
