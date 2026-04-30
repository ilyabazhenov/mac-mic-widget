import Testing
@testable import MacMicWidget

@MainActor
@Test
func coreAudioBackendUsesScriptReadWhenAvailable() throws {
    let script = MockSystemVolumeScripting(readResult: .success(73))
    let coreAudio = MockCoreAudioController()
    coreAudio.readVolumesResult = [0.2]
    let backend = CoreAudioMicrophoneBackend(scripting: script, coreAudio: coreAudio)

    let value = try backend.readInputVolume()

    #expect(abs(value - 0.73) < 0.0001)
}

@MainActor
@Test
func coreAudioBackendFallsBackToCoreAudioReadWhenScriptReturnsNil() throws {
    let script = MockSystemVolumeScripting(readResult: .success(nil))
    let coreAudio = MockCoreAudioController()
    coreAudio.readVolumesResult = [0.2, 0.8, 0.6]
    let backend = CoreAudioMicrophoneBackend(scripting: script, coreAudio: coreAudio)

    let value = try backend.readInputVolume()

    #expect(abs(value - 0.8) < 0.0001)
}

@MainActor
@Test
func coreAudioBackendThrowsWhenFallbackReadHasNoValues() throws {
    let script = MockSystemVolumeScripting(readResult: .success(nil))
    let coreAudio = MockCoreAudioController()
    coreAudio.readVolumesResult = []
    let backend = CoreAudioMicrophoneBackend(scripting: script, coreAudio: coreAudio)

    do {
        _ = try backend.readInputVolume()
        #expect(Bool(false), "Expected volumePropertyUnavailable to be thrown")
    } catch let error as MicrophoneError {
        if case .volumePropertyUnavailable = error {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Unexpected MicrophoneError case: \(error)")
        }
    } catch {
        #expect(Bool(false), "Unexpected error type: \(error)")
    }
}

@MainActor
@Test
func coreAudioBackendFallsBackToCoreAudioWriteWhenScriptReturnsFalse() throws {
    let script = MockSystemVolumeScripting(writeResult: .success(false))
    let coreAudio = MockCoreAudioController()
    coreAudio.writeVolumeResult = true
    let backend = CoreAudioMicrophoneBackend(scripting: script, coreAudio: coreAudio)

    try backend.writeInputVolume(0.35)
}

@MainActor
@Test
func coreAudioBackendThrowsWhenCoreAudioWriteIsNotSettable() throws {
    let script = MockSystemVolumeScripting(writeResult: .success(false))
    let coreAudio = MockCoreAudioController()
    coreAudio.writeVolumeResult = false
    let backend = CoreAudioMicrophoneBackend(scripting: script, coreAudio: coreAudio)

    do {
        try backend.writeInputVolume(0.35)
        #expect(Bool(false), "Expected volumePropertyNotSettable to be thrown")
    } catch let error as MicrophoneError {
        if case .volumePropertyNotSettable = error {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Unexpected MicrophoneError case: \(error)")
        }
    } catch {
        #expect(Bool(false), "Unexpected error type: \(error)")
    }
}

@MainActor
@Test
func coreAudioBackendReturnsCurrentInputDeviceNameFromCoreAudio() throws {
    let script = MockSystemVolumeScripting()
    let coreAudio = MockCoreAudioController()
    coreAudio.deviceNameResult = "AirPods Pro Microphone"
    let backend = CoreAudioMicrophoneBackend(scripting: script, coreAudio: coreAudio)

    let name = try backend.currentInputDeviceName()

    #expect(name == "AirPods Pro Microphone")
}

@MainActor
@Test
func coreAudioBackendUsesUnknownNameFallbackWhenDeviceNameMissing() throws {
    let script = MockSystemVolumeScripting()
    let coreAudio = MockCoreAudioController()
    coreAudio.deviceNameResult = "  "
    let backend = CoreAudioMicrophoneBackend(scripting: script, coreAudio: coreAudio)

    let name = try backend.currentInputDeviceName()

    #expect(name == "Unknown input device")
}
