import Foundation
import Combine

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var text: String
    let timestamp = Date()

    enum Role { case user, assistant, transcript }
}

@MainActor
final class InterviewSession: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isListening  = false
    @Published var isActive     = false
    @Published var statusText   = "Ready"
    @Published var statusColor  = StatusColor.dim
    @Published var elapsedTime  = 0

    var role          = ""
    var company       = ""
    var interviewType = ""
    var resumeText    = ""

    private var timer: Timer?
    private var startDate: Date?

    enum StatusColor { case dim, green, amber, red }

    // MARK: – Session lifecycle

    func start(role: String, company: String, type: String, resume: String) {
        self.role          = role
        self.company       = company
        self.interviewType = type
        self.resumeText    = resume
        messages.removeAll()
        isActive    = true
        isListening = true
        elapsedTime = 0
        startDate   = Date()
        status("Listening…", .green)
        startTimer()
    }

    func stop() {
        isActive    = false
        isListening = false
        stopTimer()
        status("Ready", .dim)
    }

    func toggleListening() {
        isListening.toggle()
        status(isListening ? "Listening…" : "Paused", isListening ? .green : .amber)
    }

    // MARK: – Messages

    func addTranscript(_ text: String, speaker: String = "you") {
        messages.append(ChatMessage(role: .transcript, text: "[\(speaker)] \(text)"))
    }

    func beginAIResponse() -> UUID {
        let msg = ChatMessage(role: .assistant, text: "")
        messages.append(msg)
        return msg.id
    }

    func appendChunk(_ chunk: String, to id: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].text += chunk
    }

    func clearMessages() {
        messages.removeAll()
    }

    // MARK: – Status

    func status(_ text: String, _ color: StatusColor) {
        statusText  = text
        statusColor = color
    }

    // MARK: – Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedTime += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
