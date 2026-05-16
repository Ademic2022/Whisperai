import AppKit
import SwiftUI

@MainActor
final class FABWindowController {
    private let panel: NSPanel
    private let size: CGFloat = 64

    init(onTap: @escaping () -> Void) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 64, height: 64),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered, defer: false
        )
        panel.level             = .modalPanel
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque          = false
        panel.backgroundColor   = .clear
        panel.hidesOnDeactivate = false
        panel.sharingType       = .none

        panel.contentView = NSHostingView(rootView: FABView(onTap: onTap))
        positionRight()
    }

    func show() { panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }

    private func positionRight() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: f.maxX - size + 20, y: f.maxY - 200))
    }
}

private struct FABView: View {
    let onTap: () -> Void
    @State private var isDragging = false
    @State private var offset: CGFloat = 0

    var body: some View {
        Image("AppIcon")
            .resizable()
            .scaledToFill()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.4), radius: 8)
            .onTapGesture(perform: onTap)
            .gesture(
                DragGesture()
                    .onChanged { _ in isDragging = true }
                    .onEnded   { _ in isDragging = false }
            )
    }
}
