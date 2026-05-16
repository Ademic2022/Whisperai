import SwiftUI

struct OverlayView: View {
    @ObservedObject var session: InterviewSession
    let pipeline: AIPipeline

    var body: some View {
        ZStack {
            // Window chrome
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "0b0e17"))
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)

            VStack(spacing: 0) {
                HeaderBar(session: session)

                Divider()
                    .overlay(Color.white.opacity(0.07))
                    .frame(height: 1)

                if session.isActive {
                    LiveSessionView(session: session, pipeline: pipeline)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    SetupView(session: session, pipeline: pipeline)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
        .frame(width: 480, height: 700)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: – Header

private struct HeaderBar: View {
    @ObservedObject var session: InterviewSession
    @Environment(\.openSettings) var openSettings

    var body: some View {
        HStack(spacing: 8) {
            // macOS-style close dot
            Circle()
                .fill(Color(hex: "ef4444"))
                .frame(width: 12, height: 12)
                .onTapGesture { NSApp.windows.first(where: { $0.isVisible })?.orderOut(nil) }

            Spacer().frame(width: 4)

            Text("WhisperAI")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            // Status pill
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(session.statusText)
                    .font(.system(size: 11))
                    .foregroundColor(statusColor)
            }

            Spacer().frame(width: 4)

            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Settings  ⌃⇧,")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var statusColor: Color {
        switch session.statusColor {
        case .green: return Color(hex: "10b981")
        case .amber: return Color(hex: "f59e0b")
        case .red:   return Color(hex: "ef4444")
        case .dim:   return Color(hex: "6b7280")
        }
    }
}
