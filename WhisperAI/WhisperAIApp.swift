import SwiftUI
import AppKit

@main
struct WhisperAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible scene — UI lives in the floating NSPanel + status item
        Settings { EmptyView() }
    }
}
