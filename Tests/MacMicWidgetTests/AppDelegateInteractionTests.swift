import AppKit
import Testing
@testable import MacMicWidget

@MainActor
@Test
func appDelegateClassifiesRightClickAsMuteToggle() {
    let action = AppDelegate.classifyStatusItemAction(eventType: .rightMouseDown, modifierFlags: [])
    #expect(action == .toggleMuteWithoutPopover)
}

@MainActor
@Test
func appDelegateClassifiesCtrlLeftClickAsMuteToggle() {
    let action = AppDelegate.classifyStatusItemAction(eventType: .leftMouseUp, modifierFlags: .control)
    #expect(action == .toggleMuteWithoutPopover)
}

@MainActor
@Test
func appDelegateClassifiesPlainLeftClickAsPopoverToggle() {
    let action = AppDelegate.classifyStatusItemAction(eventType: .leftMouseUp, modifierFlags: [])
    #expect(action == .togglePopover)
}

@MainActor
@Test
func appDelegateIgnoresOtherEvents() {
    let action = AppDelegate.classifyStatusItemAction(eventType: .leftMouseDown, modifierFlags: [])
    #expect(action == .ignore)
}
