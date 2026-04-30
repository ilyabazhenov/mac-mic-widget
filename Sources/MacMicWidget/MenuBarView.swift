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
    @State private var sliderVolume: Double = 0
    @State private var isSliderEditing = false
    private let sectionSpacing: CGFloat = 16
    private let contentSpacing: CGFloat = 8
    private let compactSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: compactSpacing) {
                    Text("Microphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(volumePercent)%")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
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

            VStack(alignment: .leading, spacing: contentSpacing) {
                HStack {
                    Text("Input level")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(volumePercent)%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: sliderBinding,
                    in: 0...1,
                    onEditingChanged: handleSliderEditingChanged
                )
            }

            VStack(alignment: .leading, spacing: compactSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: contentSpacing) {
                    Text("Input device")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("System default")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(Capsule())
                }
                Text(microphoneService.currentInputDeviceName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                microphoneService.toggleMute()
            } label: {
                Label(
                    microphoneService.isMuted ? "Unmute" : "Mute",
                    systemImage: microphoneService.isMuted ? "mic.fill" : "mic.slash.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(microphoneService.isMuted ? .accentColor : .red)
            .frame(maxWidth: .infinity)
            .keyboardShortcut(.space, modifiers: [])

            if let lastError = microphoneService.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle("Launch at login", isOn: launchAtLoginBinding)

            VStack(alignment: .leading, spacing: contentSpacing) {
                Toggle("Enable global hotkey", isOn: globalHotkeyBinding)
                HStack {
                    Text("Shortcut")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(globalHotkeyService.hotkeyDisplay)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: contentSpacing) {
                    Button(globalHotkeyService.isRecording ? "Press keys..." : "Record shortcut") {
                        if globalHotkeyService.isRecording {
                            globalHotkeyService.cancelRecording()
                        } else {
                            globalHotkeyService.startRecording()
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .controlSize(.regular)
                    Button("Reset to default") {
                        globalHotkeyService.resetToDefault()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .controlSize(.regular)
                }
                .frame(maxWidth: .infinity)
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
        .frame(minWidth: 280, maxWidth: 280)
        .onAppear {
            sliderVolume = Double(microphoneService.inputVolume)
            launchAtLoginService.refreshStatus()
        }
        .onChange(of: microphoneService.inputVolume) { _, newValue in
            if isSliderEditing == false {
                sliderVolume = Double(newValue)
            }
        }
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

    private var sliderBinding: Binding<Double> {
        Binding(
            get: {
                if isSliderEditing {
                    return sliderVolume
                }
                return Double(microphoneService.inputVolume)
            },
            set: { sliderVolume = $0 }
        )
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        if isEditing {
            isSliderEditing = true
            return
        }

        let committedVolume = sliderVolume
        // Keep local mode during commit to avoid one-frame snap to stale service value.
        microphoneService.setInputVolume(Float(committedVolume))
        sliderVolume = committedVolume
        isSliderEditing = false
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
