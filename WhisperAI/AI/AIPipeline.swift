import Foundation

@MainActor
final class AIPipeline {
    private let settings: AppSettings
    private var history: [(q: String, a: String)] = []
    private let maxHistory = 4

    private var role          = ""
    private var company       = ""
    private var interviewType = ""
    private var resumeText    = ""

    init(settings: AppSettings) {
        self.settings = settings
    }

    func newSession(role: String, company: String, type: String, resume: String) {
        self.role          = role
        self.company       = company
        self.interviewType = type
        self.resumeText    = resume
        history.removeAll()
    }

    // MARK: – Answer (streaming, updates session on MainActor)

    func answer(_ question: String, session: InterviewSession) async {
        let words = question.split(separator: " ").count
        guard words >= 3 else { return }

        let msgID = await MainActor.run { session.beginAIResponse() }
        await MainActor.run { session.status("Generating…", .amber) }

        var collected = ""
        do {
            for try await chunk in stream(question) {
                collected += chunk
                let c = chunk
                await MainActor.run { session.appendChunk(c, to: msgID) }
            }
            if !collected.isEmpty { history.append((question, collected)) }
            if history.count > maxHistory { history.removeFirst() }
        } catch {
            let errText = "⚠ \(error.localizedDescription)"
            await MainActor.run { session.appendChunk(errText, to: msgID) }
        }

        await MainActor.run { session.status("Listening…", .green) }
    }

    // MARK: – Streaming

    private func stream(_ question: String) -> AsyncThrowingStream<String, Error> {
        // Snapshot keys on main actor before crossing into nonisolated async context
        let groqKey      = settings.groqAPIKey
        let anthropicKey = settings.anthropicAPIKey
        let groqMdl      = settings.groqModel
        let claudeMdl    = settings.claudeModel
        let sys          = Prompts.system(role: role, company: company,
                                          type: interviewType, resume: resumeText)
        let msgs         = buildMessages(question)

        if !groqKey.isEmpty {
            return groqStream(question, key: groqKey, model: groqMdl, messages: msgs)
        } else if !anthropicKey.isEmpty {
            return anthropicStream(question, key: anthropicKey, model: claudeMdl,
                                   system: sys, messages: msgs)
        } else {
            return mockStream(question)
        }
    }

    // MARK: – Groq (OpenAI-compatible)

    private func groqStream(_ question: String, key: String, model: String,
                            messages: [[String: Any]]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            Task {
                var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
                req.httpMethod = "POST"
                req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "model":       model,
                    "max_tokens":  1024,
                    "temperature": 0.3,
                    "stream":      true,
                    "messages":    messages,
                ]
                req.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (bytes, _) = try await URLSession.shared.bytes(for: req)
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: "),
                           let data = line.dropFirst(6).data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta   = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            cont.yield(content)
                        }
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
        }
    }

    // MARK: – Anthropic

    private func anthropicStream(_ question: String, key: String, model: String,
                                 system: String, messages: [[String: Any]]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            Task {
                var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
                req.httpMethod = "POST"
                req.setValue(key,          forHTTPHeaderField: "x-api-key")
                req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "model":       model,
                    "max_tokens":  1024,
                    "temperature": 0.3,
                    "stream":      true,
                    "system":      system,
                    "messages":    messages,
                ]
                req.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (bytes, _) = try await URLSession.shared.bytes(for: req)
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: "),
                           let data = line.dropFirst(6).data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           json["type"] as? String == "content_block_delta",
                           let delta   = json["delta"] as? [String: Any],
                           let text    = delta["text"] as? String {
                            cont.yield(text)
                        }
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
        }
    }

    // MARK: – Mock

    private func mockStream(_ question: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            Task {
                let lines = [
                    "**No API key configured.**\n\n",
                    "Add a Groq or Anthropic key in Settings (⌃⇧,) ",
                    "to get real AI answers.\n\n",
                    "*Question heard:* \(question.prefix(100))"
                ]
                for line in lines {
                    cont.yield(line)
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                cont.finish()
            }
        }
    }

    // MARK: – Helpers

    private func buildMessages(_ question: String) -> [[String: Any]] {
        let sys  = [["role": "system", "content": Prompts.system(role: role, company: company,
                                                                  type: interviewType, resume: resumeText)]]
        let hist = history.flatMap { [["role":"user","content":$0.q],["role":"assistant","content":$0.a]] }
        return sys + hist + [["role":"user","content":question]]
    }
}
