import Testing
@testable import MacMicWidget

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
