import SwiftUI
import AppKit

enum MicrophoneLevelLabel: String {
    case muted = "Muted"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum MenuBarPresentationLogic {
    static func volumePercent(from inputVolume: Float) -> Int {
        Int((clamp(inputVolume) * 100).rounded())
    }

    static func levelLabel(isMuted: Bool, volumePercent: Int) -> MicrophoneLevelLabel {
        if isMuted {
            return .muted
        }
        if volumePercent < 30 {
            return .low
        }
        if volumePercent <= 60 {
            return .medium
        }
        return .high
    }

    static func levelColor(isMuted: Bool, volumePercent: Int) -> Color {
        switch levelLabel(isMuted: isMuted, volumePercent: volumePercent) {
        case .muted:
            return .secondary
        case .low:
            return .red
        case .medium:
            return .yellow
        case .high:
            return .green
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var microphoneService: MicrophoneService
    @ObservedObject var launchAtLoginService: LaunchAtLoginService
    @ObservedObject var globalHotkeyService: GlobalHotkeyService

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

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Input level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(volumePercent)%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: inputVolumeBinding,
                    in: 0...1
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Input device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("System default")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(Capsule())
                }
                Text(microphoneService.currentInputDeviceName)
                    .font(.subheadline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

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

            Toggle("Launch at login", isOn: launchAtLoginBinding)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable global hotkey", isOn: globalHotkeyBinding)
                HStack {
                    Text("Shortcut")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(globalHotkeyService.hotkeyDisplay)
                        .font(.caption.monospaced())
                }
                HStack {
                    Button(globalHotkeyService.isRecording ? "Press keys..." : "Record shortcut") {
                        if globalHotkeyService.isRecording {
                            globalHotkeyService.cancelRecording()
                        } else {
                            globalHotkeyService.startRecording()
                        }
                    }
                    .buttonStyle(.bordered)
                    Button("Reset to default") {
                        globalHotkeyService.resetToDefault()
                    }
                    .buttonStyle(.bordered)
                }
                Text(hotkeyStatusText)
                    .font(.caption)
                    .foregroundStyle(hotkeyStatusColor)
                if let hotkeyError = globalHotkeyService.lastError {
                    Text(hotkeyError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if launchAtLoginService.needsLoginItemsApproval {
                Text("Allow this app in System Settings → General → Login Items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Login Items settings") {
                    launchAtLoginService.openLoginItemsSystemSettings()
                }
                .buttonStyle(.bordered)
            }

            if let launchError = launchAtLoginService.lastError {
                Text(launchError)
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
        .onAppear { launchAtLoginService.refreshStatus() }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginService.isLaunchAtLoginEnabled },
            set: { launchAtLoginService.setLaunchAtLogin($0) }
        )
    }

    private var globalHotkeyBinding: Binding<Bool> {
        Binding(
            get: { globalHotkeyService.isEnabled },
            set: { globalHotkeyService.setEnabled($0) }
        )
    }

    private var inputVolumeBinding: Binding<Double> {
        Binding(
            get: { Double(microphoneService.inputVolume) },
            set: { microphoneService.setInputVolume(Float($0)) }
        )
    }

    private var volumePercent: Int {
        MenuBarPresentationLogic.volumePercent(from: microphoneService.inputVolume)
    }

    private var levelColor: Color {
        MenuBarPresentationLogic.levelColor(
            isMuted: microphoneService.isMuted,
            volumePercent: volumePercent
        )
    }

    private var levelLabel: String {
        MenuBarPresentationLogic.levelLabel(
            isMuted: microphoneService.isMuted,
            volumePercent: volumePercent
        ).rawValue
    }

    private var hotkeyStatusText: String {
        if globalHotkeyService.isEnabled == false {
            return "Hotkey disabled"
        }
        return globalHotkeyService.isHotkeyActive ? "Hotkey active" : "Hotkey unavailable (conflict)"
    }

    private var hotkeyStatusColor: Color {
        if globalHotkeyService.isEnabled == false {
            return .secondary
        }
        return globalHotkeyService.isHotkeyActive ? .secondary : .red
    }
}
