import AppKit
import Carbon
import Foundation

struct HotkeyConfiguration: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = HotkeyConfiguration(
        keyCode: UInt32(kVK_ANSI_Z),
        modifiers: GlobalHotkeyService.carbonFlags(from: [.option, .shift])
    )
}

enum GlobalHotkeyEvent: Equatable {
    case pressed
    case released
}

final class GlobalHotkeyService: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isHotkeyActive = false
    @Published private(set) var isRecording = false
    @Published private(set) var hotkeyDisplay: String
    @Published private(set) var lastError: String?

    private let defaults: UserDefaults
    private let toggleHandler: () -> Void
    private let eventHandler: ((GlobalHotkeyEvent) -> Void)?
    private var configuration: HotkeyConfiguration
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var localMonitor: Any?
    private let hotkeyID = EventHotKeyID(signature: 0x4D4D5751, id: 1) // "MMWQ"

    private static let enabledKey = "globalHotkey.enabled"
    private static let configurationKey = "globalHotkey.configuration"

    init(
        defaults: UserDefaults = .standard,
        toggleHandler: @escaping () -> Void,
        eventHandler: ((GlobalHotkeyEvent) -> Void)? = nil
    ) {
        self.defaults = defaults
        self.toggleHandler = toggleHandler
        self.eventHandler = eventHandler
        self.isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? false
        if
            let data = defaults.data(forKey: Self.configurationKey),
            let saved = try? JSONDecoder().decode(HotkeyConfiguration.self, from: data)
        {
            self.configuration = saved
        } else {
            self.configuration = .default
        }
        self.hotkeyDisplay = Self.displayString(for: configuration)
    }

    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        unregister()
        uninstallEventHandler()
    }

    func start() {
        installEventHandlerIfNeeded()
        if isEnabled {
            registerCurrentHotkey()
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        lastError = nil
        if enabled {
            registerCurrentHotkey()
        } else {
            unregister()
            isHotkeyActive = false
        }
    }

    func startRecording() {
        isRecording = true
        lastError = nil
        removeLocalMonitor()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.isRecording else { return event }
            return self.handleRecorderEvent(event)
        }
    }

    func cancelRecording() {
        isRecording = false
        removeLocalMonitor()
    }

    func resetToDefault() {
        applyNewConfiguration(.default)
    }

    private func handleRecorderEvent(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == UInt16(kVK_Escape) {
            cancelRecording()
            return nil
        }

        guard modifiers.intersection([.command, .control, .option, .shift]).isEmpty == false else {
            lastError = "Add at least one modifier key."
            return nil
        }
        guard Self.isModifierKey(event.keyCode) == false else {
            lastError = "Choose a non-modifier key."
            return nil
        }

        let newConfiguration = HotkeyConfiguration(
            keyCode: UInt32(event.keyCode),
            modifiers: Self.carbonFlags(from: modifiers)
        )
        applyNewConfiguration(newConfiguration)
        cancelRecording()
        return nil
    }

    private func applyNewConfiguration(_ newConfiguration: HotkeyConfiguration) {
        let oldConfiguration = configuration
        configuration = newConfiguration
        hotkeyDisplay = Self.displayString(for: newConfiguration)
        persistConfiguration()
        lastError = nil

        guard isEnabled else { return }

        registerCurrentHotkey()
        guard isHotkeyActive else {
            configuration = oldConfiguration
            hotkeyDisplay = Self.displayString(for: oldConfiguration)
            persistConfiguration()
            registerCurrentHotkey()
            lastError = "Hotkey unavailable (conflict)."
            return
        }
    }

    private func persistConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            defaults.set(data, forKey: Self.configurationKey)
        }
    }

    private func registerCurrentHotkey() {
        unregister()
        installEventHandlerIfNeeded()
        let status = RegisterEventHotKey(
            configuration.keyCode,
            configuration.modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            isHotkeyActive = true
            lastError = nil
        } else {
            isHotkeyActive = false
            lastError = "Hotkey unavailable (conflict)."
        }
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventTypes: [EventTypeSpec] = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        eventTypes.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData in
                    guard let userData else { return noErr }
                    let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userData).takeUnretainedValue()
                    return service.handleCarbonEvent(event)
                },
                buffer.count,
                baseAddress,
                selfPointer,
                &eventHandlerRef
            )
        }
    }

    private func uninstallEventHandler() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func handleCarbonEvent(_ event: EventRef?) -> OSStatus {
        guard let event else {
            return noErr
        }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else {
            return status
        }
        guard hotKeyID.signature == self.hotkeyID.signature, hotKeyID.id == self.hotkeyID.id else {
            return noErr
        }
        guard let mappedEvent = Self.mapHotkeyEvent(kind: GetEventKind(event)) else {
            return noErr
        }

        if let eventHandler {
            eventHandler(mappedEvent)
        } else if mappedEvent == .pressed {
            toggleHandler()
        }
        return noErr
    }

    private func removeLocalMonitor() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    static func carbonFlags(from modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    static func displayString(for configuration: HotkeyConfiguration) -> String {
        var prefix = ""
        if configuration.modifiers & UInt32(controlKey) != 0 { prefix += "⌃" }
        if configuration.modifiers & UInt32(optionKey) != 0 { prefix += "⌥" }
        if configuration.modifiers & UInt32(shiftKey) != 0 { prefix += "⇧" }
        if configuration.modifiers & UInt32(cmdKey) != 0 { prefix += "⌘" }
        return prefix + keyDisplayName(for: configuration.keyCode)
    }

    static func mapHotkeyEvent(kind: UInt32) -> GlobalHotkeyEvent? {
        if kind == UInt32(kEventHotKeyPressed) {
            return .pressed
        }
        if kind == UInt32(kEventHotKeyReleased) {
            return .released
        }
        return nil
    }

    private static func keyDisplayName(for keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D",
            UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F", UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H",
            UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P",
            UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R", UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
            UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2", UInt32(kVK_ANSI_3): "3",
            UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5", UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7",
            UInt32(kVK_ANSI_8): "8", UInt32(kVK_ANSI_9): "9",
        ]
        return map[keyCode] ?? "Key \(keyCode)"
    }

    private static func isModifierKey(_ keyCode: UInt16) -> Bool {
        let modifierCodes: Set<UInt16> = [
            UInt16(kVK_Command), UInt16(kVK_RightCommand),
            UInt16(kVK_Shift), UInt16(kVK_RightShift),
            UInt16(kVK_Option), UInt16(kVK_RightOption),
            UInt16(kVK_Control), UInt16(kVK_RightControl),
            UInt16(kVK_CapsLock), UInt16(kVK_Function),
        ]
        return modifierCodes.contains(keyCode)
    }
}
