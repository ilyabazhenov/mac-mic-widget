import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var microphoneService: MicrophoneService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Microphone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(volumePercent)%")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                Text(levelLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(levelColor.opacity(0.18))
                    .foregroundStyle(levelColor)
                    .clipShape(Capsule())
            }

            ProgressView(value: Double(microphoneService.inputVolume))
                .tint(levelColor)
                .frame(maxWidth: .infinity)

            Button {
                microphoneService.toggleMute()
            } label: {
                Label(
                    microphoneService.isMuted ? "Unmute microphone" : "Mute microphone",
                    systemImage: microphoneService.isMuted ? "mic.fill" : "mic.slash.fill"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .keyboardShortcut(.space, modifiers: [])

            if let lastError = microphoneService.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(minWidth: 240, maxWidth: 240)
    }

    private var volumePercent: Int {
        Int((microphoneService.inputVolume * 100).rounded())
    }

    private var levelColor: Color {
        if microphoneService.isMuted {
            return .secondary
        }
        if volumePercent < 30 {
            return .red
        }
        if volumePercent <= 60 {
            return .yellow
        }
        return .green
    }

    private var levelLabel: String {
        if microphoneService.isMuted {
            return "Muted"
        }
        if volumePercent < 30 {
            return "Low"
        }
        if volumePercent <= 60 {
            return "Medium"
        }
        return "High"
    }
}
