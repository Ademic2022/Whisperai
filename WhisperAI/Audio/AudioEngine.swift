import AVFoundation
import Combine
import ScreenCaptureKit
import Speech

@MainActor
final class AudioEngine: NSObject {
    private weak var session: InterviewSession?
    private weak var pipeline: AIPipeline?

    // Mic
    private let avEngine  = AVAudioEngine()
    private let micRecog  = SFSpeechRecognizer(locale: .init(identifier: "en-US"))
    private var micReq:   SFSpeechAudioBufferRecognitionRequest?
    private var micTask:  SFSpeechRecognitionTask?
    private var lastMicText = ""

    // System audio (ScreenCaptureKit → Speech)
    private var scStream: SCStream?
    nonisolated(unsafe) var sysReq: SFSpeechAudioBufferRecognitionRequest?
    private let sysRecog  = SFSpeechRecognizer(locale: .init(identifier: "en-US"))
    private var sysTask:  SFSpeechRecognitionTask?
    private var sysActive = false

    // VAD
    private var pendingQ    = ""
    private var silenceTimer: Timer?
    private let silenceGap  = 2.0

    // MARK: – Init

    init(session: InterviewSession, pipeline: AIPipeline) {
        self.session  = session
        self.pipeline = pipeline
    }

    // MARK: – Lifecycle

    func start() async {
        guard await requestSpeechAuth() else {
            session?.status("Speech access denied — check System Settings", .red)
            return
        }
        startMicEngine()
        startMicRecognizer()
        await startSystemAudio()
    }

    func stop() {
        stopMic()
        stopSystem()
        silenceTimer?.invalidate(); silenceTimer = nil
        pendingQ = ""
    }

    func setListening(_ on: Bool) {
        guard avEngine.isRunning != on else { return }
        if on { try? avEngine.start() } else { avEngine.pause() }
    }

    // MARK: – Speech permission

    private func requestSpeechAuth() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: – Mic capture

    private func startMicEngine() {
        let node = avEngine.inputNode
        let fmt  = node.outputFormat(forBus: 0)
        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            self?.micReq?.append(buf)
        }
        avEngine.prepare()
        try? avEngine.start()
    }

    private func startMicRecognizer() {
        micTask?.cancel()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults  = true
        req.requiresOnDeviceRecognition = false
        micReq = req

        micTask = micRecog?.recognitionTask(with: req) { [weak self] result, error in
            guard let result else { return }
            guard result.isFinal else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor [weak self] in
                guard let self, !text.isEmpty, text != self.lastMicText else { return }
                self.lastMicText = text
                self.session?.addTranscript(text, speaker: "you")
                self.startMicRecognizer()   // restart for next utterance
            }
        }
    }

    private func stopMic() {
        micTask?.cancel(); micTask = nil
        micReq?.endAudio(); micReq = nil
        if avEngine.isRunning {
            avEngine.stop()
            avEngine.inputNode.removeTap(onBus: 0)
        }
    }

    // MARK: – System audio

    private func startSystemAudio() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false)
            guard let display = content.displays.first else { return }

            let cfg = SCStreamConfiguration()
            cfg.capturesAudio = true
            cfg.sampleRate    = 16_000
            cfg.channelCount  = 1

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let stream = SCStream(filter: filter, configuration: cfg, delegate: self)
            try stream.addStreamOutput(self, type: .audio,
                                       sampleHandlerQueue: .global(qos: .userInitiated))
            try await stream.startCapture()
            scStream = stream
            sysActive = true
            startSysRecognizer()
        } catch {
            session?.status("System audio unavailable — grant Screen Recording in System Settings", .amber)
        }
    }

    private func startSysRecognizer() {
        sysTask?.cancel()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults  = true
        req.requiresOnDeviceRecognition = false
        sysReq = req

        sysTask = sysRecog?.recognitionTask(with: req) { [weak self] result, error in
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pendingQ = text
                self.session?.addTranscript(text, speaker: "interviewer")
                self.resetSilenceTimer()
            }
            if result.isFinal || error != nil {
                Task { @MainActor [weak self] in
                    guard let self, self.sysActive else { return }
                    self.startSysRecognizer()
                }
            }
        }
    }

    private func stopSystem() {
        sysActive = false
        sysTask?.cancel(); sysTask = nil
        sysReq?.endAudio(); sysReq = nil
        let s = scStream; scStream = nil
        Task { try? await s?.stopCapture() }
    }

    // MARK: – VAD / question finalizer

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceGap, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.finalizeQuestion() }
        }
    }

    private func finalizeQuestion() {
        let q = pendingQ.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let pipeline, let session else { return }
        pendingQ = ""
        startSysRecognizer()
        Task { await pipeline.answer(q, session: session) }
    }
}

// MARK: – SCStreamOutput

extension AudioEngine: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream,
                            didOutputSampleBuffer buf: CMSampleBuffer,
                            of type: SCStreamOutputType) {
        guard type == .audio,
              let req = sysReq,
              let pcm = buf.pcmBuffer() else { return }
        req.append(pcm)
    }
}

// MARK: – SCStreamDelegate

extension AudioEngine: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.sysActive = false
            self?.session?.status("System audio stopped", .amber)
        }
    }
}
