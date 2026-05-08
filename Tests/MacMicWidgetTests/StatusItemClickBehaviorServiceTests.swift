import Foundation
import Testing
@testable import MacMicWidget

@MainActor
@Test
func statusItemClickBehaviorDefaultsToOpenControlsOnLeftClick() {
    let suiteName = "statusItemClickBehaviorDefaultsToOpenControlsOnLeftClick"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let service = StatusItemClickBehaviorService(defaults: defaults)

    #expect(service.clickBehavior == .openControlsOnLeftClick)
}

@MainActor
@Test
func statusItemClickBehaviorPersistsUpdates() {
    let suiteName = "statusItemClickBehaviorPersistsUpdates"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let service = StatusItemClickBehaviorService(defaults: defaults)
    service.setClickBehavior(.toggleMuteOnLeftClick)

    let restored = StatusItemClickBehaviorService(defaults: defaults)
    #expect(restored.clickBehavior == .toggleMuteOnLeftClick)
}

@MainActor
@Test
func statusItemClickBehaviorFallsBackToDefaultForUnknownStoredValue() {
    let suiteName = "statusItemClickBehaviorFallsBackToDefaultForUnknownStoredValue"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("future-mode", forKey: StatusItemClickBehaviorService.defaultsKey)

    let service = StatusItemClickBehaviorService(defaults: defaults)

    #expect(service.clickBehavior == .openControlsOnLeftClick)
}
