import Testing
@testable import MacMicWidget

@MainActor
@Test
func launchAtLoginRefreshReflectsEnabledStatus() {
    let mock = MockLoginItemRegistering(status: .enabled)
    let service = LaunchAtLoginService(registrar: mock)
    service.refreshStatus()
    #expect(service.isLaunchAtLoginEnabled)
    #expect(!service.needsLoginItemsApproval)
}

@MainActor
@Test
func launchAtLoginToggleOnCallsRegister() {
    let mock = MockLoginItemRegistering()
    let service = LaunchAtLoginService(registrar: mock)
    service.setLaunchAtLogin(true)
    #expect(mock.registerCount == 1)
    #expect(mock.unregisterCount == 0)
    #expect(service.isLaunchAtLoginEnabled)
}

@MainActor
@Test
func launchAtLoginToggleOffCallsUnregister() {
    let mock = MockLoginItemRegistering(status: .enabled)
    let service = LaunchAtLoginService(registrar: mock)
    service.setLaunchAtLogin(false)
    #expect(mock.unregisterCount == 1)
    #expect(mock.registerCount == 0)
    #expect(!service.isLaunchAtLoginEnabled)
}

@MainActor
@Test
func launchAtLoginRegisterFailureSetsLastError() {
    struct SampleError: Error {}
    let mock = MockLoginItemRegistering()
    mock.registerError = SampleError()
    let service = LaunchAtLoginService(registrar: mock)
    service.setLaunchAtLogin(true)
    #expect(service.lastError != nil)
    #expect(!service.isLaunchAtLoginEnabled)
}

@MainActor
@Test
func launchAtLoginRequiresApprovalSetsFlag() {
    let mock = MockLoginItemRegistering(status: .requiresApproval)
    let service = LaunchAtLoginService(registrar: mock)
    service.refreshStatus()
    #expect(service.needsLoginItemsApproval)
    #expect(!service.isLaunchAtLoginEnabled)
}

@MainActor
@Test
func launchAtLoginRefreshHandlesNotRegisteredStatus() {
    let mock = MockLoginItemRegistering(status: .notRegistered)
    let service = LaunchAtLoginService(registrar: mock)

    service.refreshStatus()

    #expect(!service.needsLoginItemsApproval)
    #expect(!service.isLaunchAtLoginEnabled)
}

@MainActor
@Test
func launchAtLoginRefreshHandlesNotFoundStatus() {
    let mock = MockLoginItemRegistering(status: .notFound)
    let service = LaunchAtLoginService(registrar: mock)

    service.refreshStatus()

    #expect(!service.needsLoginItemsApproval)
    #expect(!service.isLaunchAtLoginEnabled)
}

@MainActor
@Test
func launchAtLoginUnregisterFailureSetsLastError() {
    struct SampleError: Error {}
    let mock = MockLoginItemRegistering(status: .enabled)
    mock.unregisterError = SampleError()
    let service = LaunchAtLoginService(registrar: mock)

    service.setLaunchAtLogin(false)

    #expect(service.lastError != nil)
    #expect(mock.unregisterCount == 1)
}
