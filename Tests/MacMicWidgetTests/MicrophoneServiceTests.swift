import Testing
@testable import MacMicWidget

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
func secondToggleRestoresAtLeastFivePercentWhenSavedLevelTooLow() {
    let backend = MockMicrophoneBackend(currentVolume: 0.01)
    let service = MicrophoneService(backend: backend, pollInterval: 999)
    service.refreshVolume()

    service.toggleMute()
    service.toggleMute()

    #expect(abs(backend.currentVolume - 0.05) < 0.0001)
    #expect(!service.isMuted)
}

@MainActor
@Test
func refreshVolumeSetsErrorWhenReadFails() {
    let backend = ThrowingMicrophoneBackend(readResult: .failure(ThrowingMicrophoneBackend.BackendError.readFailed))
    let service = MicrophoneService(backend: backend, pollInterval: 999)

    service.refreshVolume()

    #expect(service.lastError != nil)
}

@MainActor
@Test
func toggleMuteSetsErrorWhenWriteFails() {
    let backend = ThrowingMicrophoneBackend(readResult: .success(0.8))
    backend.writeError = ThrowingMicrophoneBackend.BackendError.writeFailed
    let service = MicrophoneService(backend: backend, pollInterval: 999)
    service.refreshVolume()

    service.toggleMute()

    #expect(service.lastError != nil)
    #expect(backend.writeCalls.count == 1)
}

@MainActor
@Test
func refreshVolumeClearsPreviousErrorAfterSuccess() {
    let backend = ThrowingMicrophoneBackend(readResult: .failure(ThrowingMicrophoneBackend.BackendError.readFailed))
    let service = MicrophoneService(backend: backend, pollInterval: 999)
    service.refreshVolume()
    #expect(service.lastError != nil)

    backend.readResult = .success(0.4)
    service.refreshVolume()

    #expect(service.lastError == nil)
    #expect(abs(service.inputVolume - 0.4) < 0.0001)
}

@MainActor
@Test
func applyObservedVolumeClampsAndTracksMutedState() {
    let backend = MockMicrophoneBackend(currentVolume: 0.3)
    let service = MicrophoneService(backend: backend, pollInterval: 999)

    service.applyObservedVolume(-1)
    #expect(abs(service.inputVolume - 0) < 0.0001)
    #expect(service.isMuted)

    service.applyObservedVolume(1.5)
    #expect(abs(service.inputVolume - 1) < 0.0001)
    #expect(!service.isMuted)
}
