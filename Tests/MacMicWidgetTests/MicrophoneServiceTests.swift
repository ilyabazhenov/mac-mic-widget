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

@MainActor
@Test
func refreshVolumeUpdatesCurrentInputDeviceName() {
    let backend = MockMicrophoneBackend(currentVolume: 0.42, deviceName: "USB Podcast Mic")
    let service = MicrophoneService(backend: backend, pollInterval: 999)

    service.refreshVolume()

    #expect(service.currentInputDeviceName == "USB Podcast Mic")
}

@MainActor
@Test
func setInputVolumeWritesClampedValueToBackend() {
    let backend = MockMicrophoneBackend(currentVolume: 0.42)
    let service = MicrophoneService(backend: backend, pollInterval: 999)

    service.setInputVolume(1.8)
    #expect(abs(backend.currentVolume - 1) < 0.0001)

    service.setInputVolume(-0.4)
    #expect(abs(backend.currentVolume - 0) < 0.0001)
}

// Slider commit contract:
// - setInputVolume applies value optimistically for immediate UI feedback.
// - refreshVolume suppresses transient backend reads that would bounce slider position.
// - final converged backend value is still accepted after the settle window.
@MainActor
@Test
func setInputVolumeSuppressesTransientObservedValuesAfterWrite() {
    let backend = SequencedReadMicrophoneBackend(
        readVolumes: [0.25, 0.4, 0.61],
        fallbackReadVolume: 0.61
    )
    let service = MicrophoneService(backend: backend, pollInterval: 999)

    service.setInputVolume(0.6)
    #expect(abs(service.inputVolume - 0.6) < 0.0001)

    service.refreshVolume()
    #expect(abs(service.inputVolume - 0.6) < 0.0001)

    service.refreshVolume()
    #expect(abs(service.inputVolume - 0.6) < 0.0001)

    service.refreshVolume()
    #expect(abs(service.inputVolume - 0.61) < 0.0001)
}

@MainActor
@Test
func setInputVolumeAppliesOptimisticValueImmediately() {
    let backend = SequencedReadMicrophoneBackend(
        readVolumes: [0.2],
        fallbackReadVolume: 0.2
    )
    let service = MicrophoneService(backend: backend, pollInterval: 999)

    service.setInputVolume(0.73)

    #expect(abs(service.inputVolume - 0.73) < 0.0001)
    #expect(service.isMuted == false)
}

@MainActor
@Test
func setInputVolumeToZeroDoesNotBounceBackOnTransientReads() {
    let backend = SequencedReadMicrophoneBackend(
        readVolumes: [0.8, 0.62, 0.0],
        fallbackReadVolume: 0.0
    )
    let service = MicrophoneService(backend: backend, pollInterval: 999)

    service.setInputVolume(0)
    #expect(abs(service.inputVolume - 0) < 0.0001)
    #expect(service.isMuted)

    service.refreshVolume()
    #expect(abs(service.inputVolume - 0) < 0.0001)
    #expect(service.isMuted)

    service.refreshVolume()
    #expect(abs(service.inputVolume - 0) < 0.0001)
    #expect(service.isMuted)

    service.refreshVolume()
    #expect(abs(service.inputVolume - 0) < 0.0001)
    #expect(service.isMuted)
}

@MainActor
@Test
func muteIfNeededReturnsFalseWhenAlreadyMuted() {
    let backend = MockMicrophoneBackend(currentVolume: 0)
    let service = MicrophoneService(backend: backend, pollInterval: 999)

    let didMute = service.muteIfNeeded()

    #expect(didMute == false)
    #expect(service.isMuted)
}

@MainActor
@Test
func unmuteToLastLevelIfNeededUsesMinimumFivePercent() {
    let backend = MockMicrophoneBackend(currentVolume: 0.01)
    let service = MicrophoneService(backend: backend, pollInterval: 999)
    service.refreshVolume()
    _ = service.muteIfNeeded()
    backend.currentVolume = 0
    service.refreshVolume()

    let didUnmute = service.unmuteToLastLevelIfNeeded()

    #expect(didUnmute)
    #expect(abs(backend.currentVolume - 0.05) < 0.0001)
}
