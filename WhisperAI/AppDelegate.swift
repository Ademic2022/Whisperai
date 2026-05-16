import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?
    private var fabController: FABWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayController = OverlayWindowController()
        fabController     = FABWindowController { [weak self] in self?.showOverlay() }

        overlayController?.onHide = { [weak self] in self?.fabController?.show() }
        overlayController?.onShow = { [weak self] in self?.fabController?.hide() }

        setupStatusItem()
        overlayController?.show()
    }

    // MARK: – Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let btn = statusItem?.button else { return }

        if let img = NSImage(named: "AppIcon") {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            btn.image = img
        }
        btn.toolTip = "WhisperAI"

        let menu = NSMenu()
        menu.addItem(withTitle: "Show WhisperAI",  action: #selector(toggleOverlay), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Settings…",       action: #selector(openSettings),  keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit WhisperAI",  action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    // MARK: – Actions

    @objc private func toggleOverlay() {
        overlayController?.toggle()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    func showOverlay() {
        overlayController?.show()
    }
}
