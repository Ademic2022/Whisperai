import SwiftUI
import UniformTypeIdentifiers

struct SetupView: View {
    @ObservedObject var session: InterviewSession
    let pipeline: AIPipeline

    @State private var role          = ""
    @State private var company       = ""
    @State private var interviewType = ""
    @State private var resumeText    = ""
    @State private var cvFileName    = ""
    @State private var isDragging    = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    fields
                    cvDropZone
                }
                .padding(20)
            }

            Divider().overlay(Color.white.opacity(0.07))
            startFooter
        }
    }

    // MARK: – Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Live Interview Copilot")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text("Set up your session context for better AI answers")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "6b7280"))
        }
    }

    // MARK: – Input fields

    private var fields: some View {
        VStack(spacing: 10) {
            StyledField("Job Role", placeholder: "e.g. Senior Backend Engineer", text: $role)
            StyledField("Company",  placeholder: "Company name",                 text: $company)
            StyledField("Interview Type", placeholder: "Technical / Behavioral / System Design",
                        text: $interviewType)
        }
    }

    // MARK: – CV drop zone

    private var cvDropZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RESUME / CV")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "6b7280"))
                .kerning(1)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(isDragging ? 0.06 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isDragging ? Color(hex: "00d4ff") : Color.white.opacity(0.1),
                                style: StrokeStyle(lineWidth: 1, dash: [5])
                            )
                    )

                VStack(spacing: 6) {
                    Image(systemName: cvFileName.isEmpty ? "doc.badge.plus" : "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(cvFileName.isEmpty ? Color.white.opacity(0.3)
                                         : Color(hex: "10b981"))
                    Text(cvFileName.isEmpty ? "Drop PDF or click to browse" : cvFileName)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .padding(.vertical, 24)
            }
            .onTapGesture { pickFile() }
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers)
            }
        }
    }

    // MARK: – Start footer

    private var startFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("⌃⇧L  listen   ⌃⇧S  OCR   ⌃⇧C  clear   ⌃⇧H  hide")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "6b7280"))
            }
            Spacer()
            Button(action: startSession) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                    Text("Start")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "00d4ff"), Color(hex: "3b82f6")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(hex: "0b0e17"))
    }

    // MARK: – Actions

    private func startSession() {
        pipeline.newSession(role: role, company: company,
                            type: interviewType, resume: resumeText)
        withAnimation(.easeInOut(duration: 0.25)) {
            session.start(role: role, company: company,
                          type: interviewType, resume: resumeText)
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .plainText]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            loadCV(from: url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url  = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async { self.loadCV(from: url) }
        }
        return true
    }

    private func loadCV(from url: URL) {
        cvFileName = url.lastPathComponent
        if url.pathExtension.lowercased() == "pdf" {
            resumeText = PDFReader.read(url) ?? ""
        } else {
            resumeText = (try? String(contentsOf: url)) ?? ""
        }
    }
}

// MARK: – Styled text field

private struct StyledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    init(_ label: String, placeholder: String, text: Binding<String>) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
