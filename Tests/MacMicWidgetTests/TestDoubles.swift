import AppKit
import CoreAudio
import ServiceManagement
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
final class ThrowingMicrophoneBackend: MicrophoneBackend {
    enum BackendError: Error {
        case readFailed
        case writeFailed
    }

    var readResult: Result<Float, Error>
    var writeError: Error?
    private(set) var writeCalls: [Float] = []

    init(readResult: Result<Float, Error>) {
        self.readResult = readResult
    }

    func readInputVolume() throws -> Float {
        try readResult.get()
    }

    func writeInputVolume(_ value: Float) throws {
        writeCalls.append(value)
        if let writeError {
            throw writeError
        }
    }
}

final class MockSystemVolumeScripting: SystemVolumeScripting {
    var readResult: Result<Float?, Error>
    var writeResult: Result<Bool, Error>

    init(
        readResult: Result<Float?, Error> = .success(nil),
        writeResult: Result<Bool, Error> = .success(true)
    ) {
        self.readResult = readResult
        self.writeResult = writeResult
    }

    func readInputVolumePercent() throws -> Float? {
        try readResult.get()
    }

    func writeInputVolumePercent(_ percent: Int) throws -> Bool {
        try writeResult.get()
    }
}

final class MockCoreAudioController: CoreAudioControlling {
    var defaultDeviceID: AudioObjectID = 101
    var readVolumesResult: [Float] = []
    var writeVolumeResult = false

    func defaultInputDeviceID() throws -> AudioObjectID {
        defaultDeviceID
    }

    func candidateInputElements(for deviceID: AudioObjectID) -> [AudioObjectPropertyElement] {
        [0, 1]
    }

    func readVolumes(
        from deviceID: AudioObjectID,
        selectors: [AudioObjectPropertySelector],
        scopes: [AudioObjectPropertyScope],
        elements: [AudioObjectPropertyElement]
    ) -> [Float] {
        readVolumesResult
    }

    func writeVolume(
        _ value: Float,
        to deviceID: AudioObjectID,
        selectors: [AudioObjectPropertySelector],
        scopes: [AudioObjectPropertyScope],
        elements: [AudioObjectPropertyElement]
    ) -> Bool {
        writeVolumeResult
    }
}
