import Testing
@testable import MacMicWidget

@Test
func menuBarTabDefaultIsMicrophone() {
    #expect(MenuBarTab.defaultTab == .microphone)
}

@Test
func menuBarTabLocalizationKeysAreStable() {
    #expect(MenuBarTab.microphone.titleKey == "menu.tab_microphone")
    #expect(MenuBarTab.settings.titleKey == "menu.tab_settings")
}

@Test
func menuBarTabPreferredPopoverHeightsAreStable() {
    #expect(MenuBarTab.microphone.preferredPopoverHeight == 360)
    #expect(MenuBarTab.settings.preferredPopoverHeight == 540)
}
