import AppKit
import Testing
@testable import MacMicWidget

@MainActor
@Test
func appDelegateClassifiesRightClickAsMuteToggle() {
    let action = AppDelegate.classifyStatusItemAction(
        eventType: .rightMouseDown,
        modifierFlags: [],
        clickBehavior: .openControlsOnLeftClick
    )
    #expect(action == .toggleMuteWithoutPopover)
}

@MainActor
@Test
func appDelegateClassifiesCtrlLeftClickAsMuteToggle() {
    let action = AppDelegate.classifyStatusItemAction(
        eventType: .leftMouseUp,
        modifierFlags: .control,
        clickBehavior: .openControlsOnLeftClick
    )
    #expect(action == .toggleMuteWithoutPopover)
}

@MainActor
@Test
func appDelegateClassifiesPlainLeftClickAsPopoverToggle() {
    let action = AppDelegate.classifyStatusItemAction(
        eventType: .leftMouseUp,
        modifierFlags: [],
        clickBehavior: .openControlsOnLeftClick
    )
    #expect(action == .togglePopover)
}

@MainActor
@Test
func appDelegateIgnoresOtherEvents() {
    let action = AppDelegate.classifyStatusItemAction(
        eventType: .leftMouseDown,
        modifierFlags: [],
        clickBehavior: .openControlsOnLeftClick
    )
    #expect(action == .ignore)
}

@MainActor
@Test
func appDelegateClassifiesPlainLeftClickAsMuteToggleInFastMode() {
    let action = AppDelegate.classifyStatusItemAction(
        eventType: .leftMouseUp,
        modifierFlags: [],
        clickBehavior: .toggleMuteOnLeftClick
    )
    #expect(action == .toggleMuteWithoutPopover)
}

@MainActor
@Test
func appDelegateClassifiesRightClickAsPopoverToggleInFastMode() {
    let action = AppDelegate.classifyStatusItemAction(
        eventType: .rightMouseDown,
        modifierFlags: [],
        clickBehavior: .toggleMuteOnLeftClick
    )
    #expect(action == .togglePopover)
}

@MainActor
@Test
func appDelegateClassifiesCtrlLeftClickAsPopoverToggleInFastMode() {
    let action = AppDelegate.classifyStatusItemAction(
        eventType: .leftMouseUp,
        modifierFlags: .control,
        clickBehavior: .toggleMuteOnLeftClick
    )
    #expect(action == .togglePopover)
}

@MainActor
@Test
func appDelegateStartsGlobalHotkeyBeforeDeferredAudioWork() {
    var events: [String] = []

    AppDelegate.startDeferredServices(
        startGlobalHotkey: { events.append("hotkey") },
        startMicrophone: { events.append("microphone") },
        refreshLaunchAtLogin: { events.append("launchAtLogin") }
    )

    #expect(events == ["hotkey", "microphone", "launchAtLogin"])
}
