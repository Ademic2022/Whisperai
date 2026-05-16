import SwiftUI

@MainActor
struct LiveSessionView: View {
    @ObservedObject var session: InterviewSession
    let pipeline: AIPipeline
    @State private var inputText = ""
    @State private var dotPhase  = 0

    private let dotTimer = Timer.publish(every: 0.38, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            feedArea
            inputBar
        }
        .background(Color(hex: "080b18"))
    }

    // MARK: – Top bar (LockedIn AI style)

    private var topBar: some View {
        HStack(spacing: 6) {
            // Left cluster
            Image(systemName: "clock")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))

            Text(timeString)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)

            pulseDots

            IconBtn(systemName: "person.badge.plus", action: {})
                .opacity(0.5)

            IconBtn(systemName: "slider.horizontal.3", action: { session.clearMessages() })
                .opacity(0.5)

            Spacer()

            // Right cluster 1
            IconBtn(systemName: "keyboard", action: {})
            IconBtn(systemName: "arrow.clockwise", action: { session.clearMessages() })

            separator

            // Right cluster 2 – audio
            IconBtn(systemName: "headphones", tint: Color(hex: "00d4ff"), action: {})
            IconBtn(
                systemName: session.isListening ? "mic" : "mic.slash",
                tint: session.isListening ? .white.opacity(0.8) : Color(hex: "ef4444"),
                action: { session.toggleListening() }
            )
            Image(systemName: "chevron.down")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))

            separator

            // Right cluster 3 – power + gear
            Button(action: { withAnimation { session.stop() } }) {
                Image(systemName: "power")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "f97316"), Color(hex: "ef4444")],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }
            .buttonStyle(.plain)
            .help("End session")

            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "00d4ff"))
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color(hex: "0d1020"))
        .overlay(Divider().overlay(Color.white.opacity(0.07)), alignment: .bottom)
        .onReceive(dotTimer) { _ in
            if session.isListening { dotPhase = (dotPhase + 1) % 3 }
        }
    }

    private var pulseDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(session.isListening
                          ? Color(hex: "00d4ff").opacity(i == dotPhase ? 1 : 0.22)
                          : Color.white.opacity(0.14))
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: dotPhase)
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 20)
    }

    // MARK: – Chat feed

    private var feedArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(session.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .onChange(of: session.messages.count) { _, _ in
                if let last = session.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: – Pill input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.white.opacity(0.07))
            HStack(spacing: 0) {
                HStack(spacing: 10) {
                    TextField("Type your message...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .onSubmit(sendMessage)

                    Button("Send", action: sendMessage)
                        .buttonStyle(SendButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(hex: "0d1020"))
        }
    }

    // MARK: – Helpers

    private var timeString: String {
        let m = session.elapsedTime / 60
        let s = session.elapsedTime % 60
        return m > 0 ? "\(m)m" : String(format: "%02d:%02d", m, s)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task {
            await pipeline.answer(text, session: session)
        }
    }
}

// MARK: – Message bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Circle()
                    .fill(Color(hex: "00d4ff").opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "brain")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "00d4ff"))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(roleLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(roleColor.opacity(0.7))

                Text(LocalizedStringKey(message.text))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(bubbleBg)
        )
    }

    private var roleLabel: String {
        switch message.role {
        case .assistant:  return "AI Assistant"
        case .transcript: return "Transcript"
        case .user:       return "You"
        }
    }

    private var roleColor: Color {
        switch message.role {
        case .assistant:  return Color(hex: "00d4ff")
        case .transcript: return Color(hex: "6b7280")
        case .user:       return Color(hex: "3b82f6")
        }
    }

    private var bubbleBg: Color {
        switch message.role {
        case .assistant:  return Color(hex: "00d4ff").opacity(0.06)
        case .transcript: return Color.white.opacity(0.03)
        case .user:       return Color(hex: "3b82f6").opacity(0.08)
        }
    }
}

// MARK: – Icon button helper

private struct IconBtn: View {
    let systemName: String
    var tint: Color = .white.opacity(0.7)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .foregroundColor(tint)
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Send button style

private struct SendButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color.white.opacity(configuration.isPressed ? 0.5 : 0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.12))
            )
    }
}
