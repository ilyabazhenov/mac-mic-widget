import ServiceManagement
import Testing
@testable import MacMicWidget

final class MockLoginItemRegistering: LoginItemRegistering, @unchecked Sendable {
    var status: SMAppService.Status
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    init(status: SMAppService.Status = .notRegistered) {
        self.status = status
    }

    func register() throws {
        registerCount += 1
        if let registerError {
            throw registerError
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .notRegistered
    }
}

@MainActor
final class MockMicrophoneBackend: MicrophoneBackend {
    var currentVolume: Float

    init(currentVolume: Float) {
        self.currentVolume = currentVolume
    }

    func readInputVolume() throws -> Float {
        currentVolume
    }

    func writeInputVolume(_ value: Float) throws {
        currentVolume = clamp(value)
    }
}

@MainActor
@Test
func togglingMutesToZeroFromNonZeroLevel() {
    let backend = MockMicrophoneBackend(currentVolume: 0.72)
    let service = MicrophoneService(backend: backend, pollInterval: 999)
    service.refreshVolume()

    service.toggleMute()

    #expect(abs(backend.currentVolume - 0) < 0.0001)
    #expect(service.isMuted)
}

@MainActor
@Test
func secondToggleRestoresLastNonZeroVolume() {
    let backend = MockMicrophoneBackend(currentVolume: 0.63)
    let service = MicrophoneService(backend: backend, pollInterval: 999)
    service.refreshVolume()

    service.toggleMute()
    service.toggleMute()

    #expect(abs(backend.currentVolume - 0.63) < 0.0001)
    #expect(!service.isMuted)
}

@MainActor
@Test
func externalVolumeChangeUpdatesRestoreTarget() {
    let backend = MockMicrophoneBackend(currentVolume: 0.4)
    let service = MicrophoneService(backend: backend, pollInterval: 999)
    service.refreshVolume()

    backend.currentVolume = 0.88
    service.refreshVolume()
    service.toggleMute()
    service.toggleMute()

    #expect(abs(backend.currentVolume - 0.88) < 0.0001)
    #expect(abs(service.inputVolume - 0.88) < 0.0001)
}

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
