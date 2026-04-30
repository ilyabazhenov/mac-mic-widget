import CoreAudio
import Foundation

@MainActor
protocol MicrophoneBackend {
    func readInputVolume() throws -> Float
    func writeInputVolume(_ value: Float) throws
}

struct CoreAudioMicrophoneBackend: MicrophoneBackend {
    func readInputVolume() throws -> Float {
        if let scriptVolume = try readInputVolumeFromSystemSettings() {
            return clamp(scriptVolume / 100)
        }

        let deviceID = try defaultInputDeviceID()
        let elements = candidateInputElements(for: deviceID)
        let selectors: [AudioObjectPropertySelector] = [kAudioDevicePropertyVolumeScalar]
        let scopes: [AudioObjectPropertyScope] = [
            kAudioDevicePropertyScopeInput,
            kAudioObjectPropertyScopeGlobal,
        ]
        let observedVolumes = readVolumes(
            from: deviceID,
            selectors: selectors,
            scopes: scopes,
            elements: elements
        )

        guard let effectiveVolume = observedVolumes.max() else {
            throw MicrophoneError.volumePropertyUnavailable
        }
        return effectiveVolume
    }

    func writeInputVolume(_ value: Float) throws {
        if try writeInputVolumeToSystemSettings(percent: Int((clamp(value) * 100).rounded())) {
            return
        }

        let deviceID = try defaultInputDeviceID()
        let elements = candidateInputElements(for: deviceID)
        let selectors: [AudioObjectPropertySelector] = [kAudioDevicePropertyVolumeScalar]
        let scopes: [AudioObjectPropertyScope] = [
            kAudioDevicePropertyScopeInput,
            kAudioObjectPropertyScopeGlobal,
        ]
        let wroteAtLeastOne = writeVolume(
            clamp(value),
            to: deviceID,
            selectors: selectors,
            scopes: scopes,
            elements: elements
        )

        guard wroteAtLeastOne else {
            throw MicrophoneError.volumePropertyNotSettable
        }
    }

    private func defaultInputDeviceID() throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr else {
            throw MicrophoneError.coreAudioFailure(status)
        }
        guard deviceID != kAudioObjectUnknown else {
            throw MicrophoneError.defaultInputDeviceUnavailable
        }

        return deviceID
    }

    private func readInputVolumeFromSystemSettings() throws -> Float? {
        let output = try runAppleScript("input volume of (get volume settings)")
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Float(trimmed) else {
            return nil
        }
        return min(max(value, 0), 100)
    }

    private func writeInputVolumeToSystemSettings(percent: Int) throws -> Bool {
        _ = try runAppleScript("set volume input volume \(max(0, min(100, percent)))")
        return true
    }

    private func runAppleScript(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let message = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw MicrophoneError.scriptFailure(message ?? "osascript failed")
        }

        return String(data: outputData, encoding: .utf8) ?? ""
    }

    private func readVolumes(
        from deviceID: AudioObjectID,
        selectors: [AudioObjectPropertySelector],
        scopes: [AudioObjectPropertyScope],
        elements: [AudioObjectPropertyElement]
    ) -> [Float] {
        var result: [Float] = []
        for selector in selectors {
            for scope in scopes {
                for element in elements {
                    var address = AudioObjectPropertyAddress(
                        mSelector: selector,
                        mScope: scope,
                        mElement: element
                    )
                    guard AudioObjectHasProperty(deviceID, &address) else {
                        continue
                    }

                    var volume: Float32 = 0
                    var size = UInt32(MemoryLayout<Float32>.size)
                    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
                    if status == noErr {
                        result.append(clamp(volume))
                    }
                }
            }
        }
        return result
    }

    private func writeVolume(
        _ value: Float,
        to deviceID: AudioObjectID,
        selectors: [AudioObjectPropertySelector],
        scopes: [AudioObjectPropertyScope],
        elements: [AudioObjectPropertyElement]
    ) -> Bool {
        var wroteAtLeastOne = false
        for selector in selectors {
            for scope in scopes {
                for element in elements {
                    var address = AudioObjectPropertyAddress(
                        mSelector: selector,
                        mScope: scope,
                        mElement: element
                    )
                    guard AudioObjectHasProperty(deviceID, &address) else {
                        continue
                    }

                    var isSettable = DarwinBoolean(false)
                    let settableStatus = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
                    guard settableStatus == noErr, isSettable.boolValue else {
                        continue
                    }

                    var scalar = Float32(value)
                    let size = UInt32(MemoryLayout<Float32>.size)
                    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &scalar)
                    if status == noErr {
                        wroteAtLeastOne = true
                    }
                }
            }
        }
        return wroteAtLeastOne
    }

    private func candidateInputElements(for deviceID: AudioObjectID) -> [AudioObjectPropertyElement] {
        var channelsAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyPreferredChannelsForStereo,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var stereoChannels = [UInt32](repeating: 0, count: 2)
        var size = UInt32(MemoryLayout<UInt32>.size * stereoChannels.count)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &channelsAddress,
            0,
            nil,
            &size,
            &stereoChannels
        )

        var result: [AudioObjectPropertyElement] = [kAudioObjectPropertyElementMain]
        if status == noErr {
            let preferred = stereoChannels.filter { $0 > 0 }
            if preferred.isEmpty {
                result.append(1)
                result.append(2)
            } else {
                result.append(contentsOf: preferred)
            }
        } else {
            result.append(1)
            result.append(2)
        }
        return Array(Set(result))
    }
}

enum MicrophoneError: Error, LocalizedError {
    case defaultInputDeviceUnavailable
    case volumePropertyUnavailable
    case volumePropertyNotSettable
    case coreAudioFailure(OSStatus)
    case scriptFailure(String)

    var errorDescription: String? {
        switch self {
        case .defaultInputDeviceUnavailable:
            return "Default input device is unavailable."
        case .volumePropertyUnavailable:
            return "Input volume property is unavailable for this device."
        case .volumePropertyNotSettable:
            return "Input volume cannot be changed for this device."
        case let .coreAudioFailure(status):
            return "CoreAudio error: \(status)."
        case let .scriptFailure(message):
            return "System volume script failed: \(message)"
        }
    }
}

@MainActor
final class MicrophoneService: ObservableObject {
    @Published private(set) var inputVolume: Float = 0
    @Published private(set) var isMuted = true
    @Published private(set) var lastError: String?

    private let backend: MicrophoneBackend
    private let pollInterval: TimeInterval
    private var timer: Timer?
    private(set) var lastNonZeroInputVolume: Float = 1

    init(backend: MicrophoneBackend = CoreAudioMicrophoneBackend(), pollInterval: TimeInterval = 0.5) {
        self.backend = backend
        self.pollInterval = pollInterval
    }

    func start() {
        refreshVolume()
        timer?.invalidate()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshVolume()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func toggleMute() {
        do {
            let current = try backend.readInputVolume()
            if current > 0.0001 {
                lastNonZeroInputVolume = current
                try backend.writeInputVolume(0)
            } else {
                let restoreValue = max(lastNonZeroInputVolume, 0.05)
                try backend.writeInputVolume(restoreValue)
            }
            lastError = nil
            refreshVolume()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshVolume() {
        do {
            let volume = try backend.readInputVolume()
            applyObservedVolume(volume)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func applyObservedVolume(_ volume: Float) {
        inputVolume = clamp(volume)
        isMuted = inputVolume <= 0.0001
        if inputVolume > 0.0001 {
            lastNonZeroInputVolume = inputVolume
        }
    }
}

func clamp(_ value: Float) -> Float {
    min(max(value, 0), 1)
}
