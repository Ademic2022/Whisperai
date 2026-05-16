import AppKit
import Combine
import SwiftUI

@MainActor
final class OverlayWindowController {
    private let panel: NSPanel
    private let session  = InterviewSession()
    private let pipeline: AIPipeline
    private let audio:   AudioEngine
    private var subs     = Set<AnyCancellable>()

    var onHide: (() -> Void)?
    var onShow: (() -> Void)?

    init() {
        pipeline = AIPipeline(settings: .shared)
        audio    = AudioEngine(session: session, pipeline: pipeline)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 700),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.level                = .modalPanel          // above all normal windows
        panel.collectionBehavior   = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque             = false
        panel.backgroundColor      = .clear
        panel.hasShadow            = true
        panel.hidesOnDeactivate    = false
        panel.sharingType          = .none                // invisible to screen share / Zoom

        let root = OverlayView(session: session, pipeline: pipeline)
            .environment(\.openSettings, { SettingsWindowController.shared.show() })
        panel.contentView = NSHostingView(rootView: root)
        panel.alphaValue  = AppSettings.shared.overlayOpacity

        positionTopRight()
        bindAudio()
    }

    // MARK: – Audio binding

    private func bindAudio() {
        session.$isActive
            .dropFirst()
            .sink { [weak self] active in
                guard let self else { return }
                if active { Task { await self.audio.start() } }
                else      { self.audio.stop() }
            }
            .store(in: &subs)

        session.$isListening
            .dropFirst()
            .sink { [weak self] on in self?.audio.setListening(on) }
            .store(in: &subs)
    }

    // MARK: – Visibility

    func show() {
        panel.orderFrontRegardless()
        onShow?()
    }

    func hide() {
        panel.orderOut(nil)
        onHide?()
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    // MARK: – Opacity (live update from Settings)

    func setOpacity(_ value: Double) {
        panel.alphaValue = value
    }

    // MARK: – Private

    private func positionTopRight() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: f.maxX - panel.frame.width  - 20,
            y: f.maxY - panel.frame.height - 10
        ))
    }
}

// MARK: – Environment key for opening settings

struct OpenSettingsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openSettings: () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}
