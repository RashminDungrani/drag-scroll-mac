// ─────────────────────────────────────────────────────────────
// DragScroll Diagnostic — Detects mouse button numbers
// ─────────────────────────────────────────────────────────────
// Run from Terminal to see live output.
// Press any extra mouse button to see its button number.
// Press Ctrl+C to quit.
// ─────────────────────────────────────────────────────────────

import Cocoa
import CoreGraphics

final class DiagController: NSObject {
    private var eventTap: CFMachPort?

    func start() {
        // Check accessibility
        let trusted = AXIsProcessTrusted()
        print("╔══════════════════════════════════════════════╗")
        print("║   DragScroll — Button Diagnostic Tool        ║")
        print("╚══════════════════════════════════════════════╝")
        print("")
        print("  Accessibility trusted: \(trusted)")
        print("")

        if !trusted {
            print("  ❌ NOT TRUSTED — cannot intercept events.")
            print("     Go to System Settings → Privacy & Security → Accessibility")
            print("     Add this app and toggle it ON.")
            print("")

            // Prompt for access
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            print("  Waiting for you to grant access... Restart after granting.")
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 30))
            return
        }

        // Listen to ALL mouse events
        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,   // passive — don't block events
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let ctrl = Unmanaged<DiagController>.fromOpaque(refcon)
                    .takeUnretainedValue()
                ctrl.logEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("  ❌ Failed to create event tap!")
            print("     This usually means Accessibility access was not granted.")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("  ✅ Event tap created successfully!")
        print("")
        print("  ──────────────────────────────────────────────")
        print("  Now click your mouse buttons (especially button 5).")
        print("  Each event will be logged below.")
        print("  Press Ctrl+C to quit.")
        print("  ──────────────────────────────────────────────")
        print("")
    }

    private var eventCount = 0

    func logEvent(type: CGEventType, event: CGEvent) {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        let deltaX = event.getDoubleValueField(.mouseEventDeltaX)
        let deltaY = event.getDoubleValueField(.mouseEventDeltaY)

        let typeName: String
        switch type {
        case .leftMouseDown:    typeName = "LeftMouseDown"
        case .leftMouseUp:      typeName = "LeftMouseUp"
        case .rightMouseDown:   typeName = "RightMouseDown"
        case .rightMouseUp:     typeName = "RightMouseUp"
        case .otherMouseDown:   typeName = "OtherMouseDown"
        case .otherMouseUp:     typeName = "OtherMouseUp"
        case .otherMouseDragged: typeName = "OtherMouseDragged"
        case .mouseMoved:       typeName = "MouseMoved"
        case .tapDisabledByTimeout: typeName = "TapDisabledByTimeout"
        case .tapDisabledByUserInput: typeName = "TapDisabledByUserInput"
        default:                typeName = "Other(\(type.rawValue))"
        }

        // Only log button events and drags (skip plain mouseMoved to reduce noise)
        if type == .mouseMoved { return }

        eventCount += 1
        let timestamp = DateFormatter.localizedString(
            from: Date(), dateStyle: .none, timeStyle: .medium
        )

        print("  [\(eventCount)] \(timestamp)  \(typeName)")
        print("        Button Number: \(button)")
        if type == .otherMouseDragged {
            print("        Delta: dx=\(String(format: "%.1f", deltaX)), dy=\(String(format: "%.1f", deltaY))")
        }
        print("")

        // Highlight button 5 detection
        if (type == .otherMouseDown || type == .otherMouseUp) && button >= 3 {
            print("  ⭐ EXTRA BUTTON DETECTED: Button \(button + 1) (CGEvent index \(button))")
            print("     → Use targetButton = \(button) in DragScroll config")
            print("")
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon

let ctrl = DiagController()
ctrl.start()

// Run the event loop
RunLoop.current.run()
