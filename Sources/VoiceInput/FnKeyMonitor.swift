import Cocoa

final class FnKeyMonitor {
    private let onFnDown: () -> Void
    private let onFnUp: () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnIsDown = false

    init(onFnDown: @escaping () -> Void, onFnUp: @escaping () -> Void) {
        self.onFnDown = onFnDown
        self.onFnUp = onFnUp
    }

    func start() {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[FnKeyMonitor] Failed to create event tap. Grant Accessibility permission in System Settings > Privacy & Security > Accessibility.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let fnPressed = flags.contains(.maskSecondaryFn)
        // Check that only Fn is pressed (no other modifiers like Cmd, Opt, etc.)
        let otherModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let hasOtherModifiers = !flags.intersection(otherModifiers).isEmpty

        if fnPressed && !fnIsDown && !hasOtherModifiers {
            fnIsDown = true
            onFnDown()
            // Suppress the event to prevent emoji picker
            return nil
        } else if !fnPressed && fnIsDown {
            fnIsDown = false
            onFnUp()
            // Suppress the event
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
