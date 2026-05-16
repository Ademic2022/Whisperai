import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false
            )
            win.title = "WhisperAI — Settings"
            win.contentView = NSHostingView(rootView: SettingsView())
            win.center()
            window = win
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject private var s = AppSettings.shared
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                        .transition(.opacity)
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    group("AI PROVIDER") {
                        SecretField(label: "Groq API Key",      text: $s.groqAPIKey)
                        SecretField(label: "Anthropic API Key", text: $s.anthropicAPIKey)
                        SecretField(label: "Deepgram API Key",  text: $s.deepgramAPIKey)
                    }

                    group("MODELS") {
                        Picker("Groq Model", selection: $s.groqModel) {
                            Text("Llama 3.3 70B").tag("llama-3.3-70b-versatile")
                            Text("Llama 3.1 8B").tag("llama-3.1-8b-instant")
                        }
                        Picker("Claude Model", selection: $s.claudeModel) {
                            Text("Claude Sonnet 4.6").tag("claude-sonnet-4-6")
                            Text("Claude Haiku 4.5").tag("claude-haiku-4-5-20251001")
                            Text("Claude Opus 4.7").tag("claude-opus-4-7")
                        }
                    }

                    group("OVERLAY") {
                        HStack {
                            Text("Opacity")
                                .foregroundColor(.secondary)
                            Slider(value: $s.overlayOpacity, in: 0.2...1.0)
                            Text("\(Int(s.overlayOpacity * 100))%")
                                .foregroundColor(.secondary)
                                .frame(width: 36)
                        }
                    }

                    group("AUDIO") {
                        HStack {
                            Text("VAD Threshold")
                                .foregroundColor(.secondary)
                            Slider(value: $s.vadThreshold, in: 0.001...0.05)
                            Text(String(format: "%.3f", s.vadThreshold))
                                .foregroundColor(.secondary)
                                .frame(width: 42)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.escape)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .kerning(1)
            content()
        }
    }

    private func save() {
        s.save()
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saved = false }
        }
    }
}

private struct SecretField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            SecureField("••••••••", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
        }
    }
}
