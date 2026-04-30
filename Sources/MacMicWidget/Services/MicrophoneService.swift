import Foundation

@MainActor
protocol MicrophoneBackend {
    func readInputVolume() throws -> Float
    func writeInputVolume(_ value: Float) throws
    func currentInputDeviceName() throws -> String
}

@MainActor
final class MicrophoneService: ObservableObject {
    @Published private(set) var inputVolume: Float = 0
    @Published private(set) var isMuted = true
    @Published private(set) var lastError: String?
    @Published private(set) var currentInputDeviceName = "Unknown input device"

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

    func setInputVolume(_ value: Float) {
        do {
            try backend.writeInputVolume(clamp(value))
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
            currentInputDeviceName = try backend.currentInputDeviceName()
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
