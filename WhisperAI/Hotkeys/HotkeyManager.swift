import AppKit
import Carbon

final class HotkeyManager {
    var onToggleListen:   (() -> Void)?
    var onToggleOverlay:  (() -> Void)?
    var onClear:          (() -> Void)?
    var onOCR:            (() -> Void)?
    var onOpenSettings:   (() -> Void)?

    private var monitors: [Any] = []

    init() { register() }

    private func register() {
        // Global monitor for key-down events (works even when app is not active)
        let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }
        if let m { monitors.append(m) }
    }

    private func handle(_ event: NSEvent) {
        let ctrl  = event.modifierFlags.contains(.control)
        let shift = event.modifierFlags.contains(.shift)
        guard ctrl && shift else { return }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "l": onToggleListen?()
        case "h": onToggleOverlay?()
        case "c": onClear?()
        case "s": onOCR?()
        case ",": onOpenSettings?()
        default:  break
        }
    }

    deinit {
        monitors.forEach { NSEvent.removeMonitor($0) }
    }
}
