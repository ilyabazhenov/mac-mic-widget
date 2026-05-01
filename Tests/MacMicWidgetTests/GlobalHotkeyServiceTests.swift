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
    #expect(GlobalHotkeyService.displayString(for: .default) == "⌥⇧Z")
}

@Test
func globalHotkeyMapsCarbonEventKinds() {
    #expect(GlobalHotkeyService.mapHotkeyEvent(kind: UInt32(kEventHotKeyPressed)) == .pressed)
    #expect(GlobalHotkeyService.mapHotkeyEvent(kind: UInt32(kEventHotKeyReleased)) == .released)
    #expect(GlobalHotkeyService.mapHotkeyEvent(kind: 9999) == nil)
}
