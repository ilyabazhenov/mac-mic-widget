import Combine
import Foundation
import ServiceManagement

/// Abstraction for `SMAppService.mainApp` to enable unit testing without real login item registration.
protocol LoginItemRegistering: Sendable {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

struct SystemLoginItemRegistering: LoginItemRegistering {
    var status: SMAppService.Status { SMAppService.mainApp.status }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

@MainActor
final class LaunchAtLoginService: ObservableObject {
    private let registrar: LoginItemRegistering

    @Published private(set) var isLaunchAtLoginEnabled = false
    @Published private(set) var needsLoginItemsApproval = false
    @Published private(set) var lastError: String?

    init(registrar: LoginItemRegistering = SystemLoginItemRegistering()) {
        self.registrar = registrar
    }

    func refreshStatus() {
        applyStatus(registrar.status)
        lastError = nil
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try registrar.register()
            } else {
                try registrar.unregister()
            }
            applyStatus(registrar.status)
        } catch {
            lastError = error.localizedDescription
            applyStatus(registrar.status)
        }
    }

    func openLoginItemsSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func applyStatus(_ status: SMAppService.Status) {
        switch status {
        case .enabled:
            isLaunchAtLoginEnabled = true
            needsLoginItemsApproval = false
        case .requiresApproval:
            isLaunchAtLoginEnabled = false
            needsLoginItemsApproval = true
        case .notRegistered, .notFound:
            isLaunchAtLoginEnabled = false
            needsLoginItemsApproval = false
        @unknown default:
            isLaunchAtLoginEnabled = false
            needsLoginItemsApproval = false
        }
    }
}
