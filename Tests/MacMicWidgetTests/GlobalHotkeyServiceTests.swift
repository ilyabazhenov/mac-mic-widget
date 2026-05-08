import AppKit
import Carbon
import Testing
@testable import MacMicWidget

@Test
func globalHotkeyCarbonFlagsMapsModifiers() {
    let flags = GlobalHotkeyService.carbonFlags(from: [.command, .option, .control])
    #expect(flags & UInt32(cmdKey) != 0)
    #expect(flags & UInt32(optionKey) != 0)
    #expect(flags & UInt32(controlKey) != 0)
    #expect(flags & UInt32(shiftKey) == 0)
}

@Test
func globalHotkeyDisplayStringUsesReadableSymbols() {
    let configuration = HotkeyConfiguration(
        keyCode: UInt32(kVK_ANSI_M),
        modifiers: UInt32(cmdKey | optionKey | controlKey)
    )
    #expect(GlobalHotkeyService.displayString(for: configuration) == "⌃⌥⌘M")
}

@Test
func globalHotkeyDefaultConfigurationDisplayString() {
    #expect(GlobalHotkeyService.displayString(for: .default) == "⌃⌥M")
}

@Test
func globalHotkeyMapsCarbonEventKinds() {
    #expect(GlobalHotkeyService.mapHotkeyEvent(kind: UInt32(kEventHotKeyPressed)) == .pressed)
    #expect(GlobalHotkeyService.mapHotkeyEvent(kind: UInt32(kEventHotKeyReleased)) == .released)
    #expect(GlobalHotkeyService.mapHotkeyEvent(kind: 9999) == nil)
}

@Test
func globalHotkeyMigratesLegacyDefaultConfiguration() throws {
    let defaults = try temporaryDefaults()
    let legacyDefault = HotkeyConfiguration(
        keyCode: UInt32(kVK_ANSI_Z),
        modifiers: GlobalHotkeyService.carbonFlags(from: [.option, .shift])
    )
    defaults.set(try JSONEncoder().encode(legacyDefault), forKey: hotkeyConfigurationDefaultsKey)

    let service = GlobalHotkeyService(defaults: defaults, toggleHandler: { })

    #expect(service.hotkeyDisplay == "⌃⌥M")
    let stored = try #require(storedHotkeyConfiguration(in: defaults))
    #expect(stored == .default)
}

@Test
func globalHotkeyKeepsCustomStoredConfiguration() throws {
    let defaults = try temporaryDefaults()
    let custom = HotkeyConfiguration(
        keyCode: UInt32(kVK_ANSI_Q),
        modifiers: GlobalHotkeyService.carbonFlags(from: [.command, .option])
    )
    defaults.set(try JSONEncoder().encode(custom), forKey: hotkeyConfigurationDefaultsKey)

    let service = GlobalHotkeyService(defaults: defaults, toggleHandler: { })

    #expect(service.hotkeyDisplay == "⌥⌘Q")
    let stored = try #require(storedHotkeyConfiguration(in: defaults))
    #expect(stored == custom)
}

private func temporaryDefaults() throws -> UserDefaults {
    let suiteName = "GlobalHotkeyServiceTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

private func storedHotkeyConfiguration(in defaults: UserDefaults) -> HotkeyConfiguration? {
    guard let data = defaults.data(forKey: hotkeyConfigurationDefaultsKey) else {
        return nil
    }
    return try? JSONDecoder().decode(HotkeyConfiguration.self, from: data)
}

private let hotkeyConfigurationDefaultsKey = "globalHotkey.configuration"
