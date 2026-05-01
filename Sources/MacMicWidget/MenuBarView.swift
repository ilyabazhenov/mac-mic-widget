import SwiftUI
import AppKit

enum MicrophoneLevelLabel {
    case muted
    case low
    case medium
    case high
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

enum MenuBarTab: String, CaseIterable, Identifiable {
    case microphone
    case settings

    static let defaultTab: MenuBarTab = .microphone

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .microphone:
            return "menu.tab_microphone"
        case .settings:
            return "menu.tab_settings"
        }
    }

    var preferredPopoverHeight: CGFloat {
        switch self {
        case .microphone:
            return 360
        case .settings:
            return 540
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var microphoneService: MicrophoneService
    @ObservedObject var launchAtLoginService: LaunchAtLoginService
    @ObservedObject var globalHotkeyService: GlobalHotkeyService
    @ObservedObject var visualFeedbackService: VisualFeedbackService
    @ObservedObject var localizationService: LocalizationService
    @ObservedObject var audioFeedbackService: AudioFeedbackService
    @ObservedObject var holdToUnmuteService: HoldToUnmuteService
    let onToggleMuteFromPopover: () -> Void
    let onSetInputVolumeFromPopover: (Float) -> Void
    let onTabChanged: (MenuBarTab) -> Void
    @State private var sliderVolume: Double = 0
    @State private var isSliderEditing = false
    @State private var selectedTab: MenuBarTab = MenuBarTab.defaultTab
    private let sectionSpacing: CGFloat = 16
    private let contentSpacing: CGFloat = 8
    private let compactSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            Picker("", selection: $selectedTab) {
                ForEach(MenuBarTab.allCases) { tab in
                    Text(localizationService.string(tab.titleKey)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            .labelsHidden()
            .accessibilityLabel(localizationService.string("menu.tab_selector"))

            Group {
                if selectedTab == .microphone {
                    microphoneTabView
                } else {
                    settingsTabView
                }
            }
        }
        .padding(14)
        .frame(minWidth: 300, maxWidth: 300)
        .onAppear {
            sliderVolume = Double(microphoneService.inputVolume)
            launchAtLoginService.refreshStatus()
            onTabChanged(selectedTab)
        }
        .onChange(of: microphoneService.inputVolume) { _, newValue in
            if isSliderEditing == false {
                sliderVolume = Double(newValue)
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            onTabChanged(newValue)
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

    private var holdToUnmuteBinding: Binding<Bool> {
        Binding(
            get: { holdToUnmuteService.isEnabled },
            set: { holdToUnmuteService.setEnabled($0) }
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
        onSetInputVolumeFromPopover(Float(committedVolume))
        sliderVolume = committedVolume
        isSliderEditing = false
    }

    private var soundFeedbackBinding: Binding<Bool> {
        Binding(
            get: { audioFeedbackService.isEnabled },
            set: { audioFeedbackService.setEnabled($0) }
        )
    }

    private var soundVolumeBinding: Binding<Double> {
        Binding(
            get: { Double(audioFeedbackService.volume) },
            set: { audioFeedbackService.setVolume(Float($0)) }
        )
    }

    private var soundPresetBinding: Binding<AudioFeedbackService.SoundPreset> {
        Binding(
            get: { audioFeedbackService.soundPreset },
            set: { audioFeedbackService.setSoundPreset($0) }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { localizationService.selectedLanguage },
            set: { localizationService.setLanguage($0) }
        )
    }

    private var visualFeedbackBinding: Binding<Bool> {
        Binding(
            get: { visualFeedbackService.isEnabled },
            set: { visualFeedbackService.setEnabled($0) }
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
        let label = MenuBarPresentationLogic.levelLabel(
            isMuted: microphoneService.isMuted,
            volumePercent: volumePercent
        )
        switch label {
        case .muted:
            return localizationService.string("level.muted")
        case .low:
            return localizationService.string("level.low")
        case .medium:
            return localizationService.string("level.medium")
        case .high:
            return localizationService.string("level.high")
        }
    }

    private var hotkeyStatusText: String {
        if globalHotkeyService.isEnabled == false {
            return localizationService.string("menu.hotkey_disabled")
        }
        return globalHotkeyService.isHotkeyActive
            ? localizationService.string("menu.hotkey_active")
            : localizationService.string("menu.hotkey_unavailable")
    }

    private var hotkeyStatusColor: Color {
        if globalHotkeyService.isEnabled == false {
            return .secondary
        }
        return globalHotkeyService.isHotkeyActive ? .secondary : .red
    }

    private var microphoneTabView: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: compactSpacing) {
                    Text(localizationService.string("menu.microphone"))
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
                    Text(localizationService.string("menu.input_level"))
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
                    Text(localizationService.string("menu.input_device"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(localizationService.string("menu.system_default"))
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
                onToggleMuteFromPopover()
            } label: {
                Label(
                    microphoneService.isMuted
                        ? localizationService.string("menu.unmute")
                        : localizationService.string("menu.mute"),
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
        }
    }

    private var settingsTabView: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            Toggle(localizationService.string("menu.launch_at_login"), isOn: launchAtLoginBinding)

            VStack(alignment: .leading, spacing: contentSpacing) {
                Text(localizationService.string("menu.hotkey_section"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Toggle(localizationService.string("menu.enable_global_hotkey"), isOn: globalHotkeyBinding)
                Toggle(localizationService.string("menu.enable_hold_to_unmute"), isOn: holdToUnmuteBinding)
                    .disabled(globalHotkeyService.isEnabled == false)
                HStack {
                    Text(localizationService.string("menu.shortcut"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(globalHotkeyService.hotkeyDisplay)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: contentSpacing) {
                    Button(
                        globalHotkeyService.isRecording
                            ? localizationService.string("menu.press_keys")
                            : localizationService.string("menu.record_shortcut")
                    ) {
                        if globalHotkeyService.isRecording {
                            globalHotkeyService.cancelRecording()
                        } else {
                            globalHotkeyService.startRecording()
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .controlSize(.regular)
                    Button(localizationService.string("menu.reset_default")) {
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

            VStack(alignment: .leading, spacing: contentSpacing) {
                Text(localizationService.string("menu.feedback_section"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Toggle(localizationService.string("menu.show_visual_notifications"), isOn: visualFeedbackBinding)
                Toggle(localizationService.string("menu.play_sound_notifications"), isOn: soundFeedbackBinding)
                VStack(alignment: .leading, spacing: compactSpacing) {
                    Text(localizationService.string("menu.sound_preset"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: soundPresetBinding) {
                        ForEach(AudioFeedbackService.SoundPreset.allCases, id: \.self) { preset in
                            Text(localizationService.string(preset.localizationKey)).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(audioFeedbackService.isEnabled == false)
                }
                HStack {
                    Text(localizationService.string("menu.sound_volume"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int((audioFeedbackService.volume * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: soundVolumeBinding, in: 0...1)
                    .disabled(audioFeedbackService.isEnabled == false)
            }

            VStack(alignment: .leading, spacing: contentSpacing) {
                Text(localizationService.string("menu.language_section"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                VStack(spacing: contentSpacing) {
                    languageRowButton(.system)
                    languageRowButton(.english)
                    languageRowButton(.russian)
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel(localizationService.string("menu.language_section"))
            }

            if launchAtLoginService.needsLoginItemsApproval {
                Text(localizationService.string("menu.allow_login_items"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(localizationService.string("menu.open_login_items")) {
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

            Button(localizationService.string("menu.quit")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func languageRowButton(_ language: AppLanguage) -> some View {
        Button {
            languageBinding.wrappedValue = language
        } label: {
            HStack {
                Text(localizationService.displayName(for: language))
                    .lineLimit(1)
                Spacer()
                if languageBinding.wrappedValue == language {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
