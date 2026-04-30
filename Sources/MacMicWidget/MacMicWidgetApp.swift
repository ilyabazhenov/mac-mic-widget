import SwiftUI
import Foundation
import AppKit
import Combine

@main
struct MacMicWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let microphoneService = MicrophoneService()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NSApp.setActivationPolicy(.accessory)
        microphoneService.start()
        setupStatusItem()
        setupPopover()
        bindStateUpdates()
        updateStatusButton()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }

        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseDown])
        button.imagePosition = .imageOnly
        button.appearsDisabled = false

        statusItem = item
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 260, height: 220)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(microphoneService: microphoneService)
        )
    }

    private func bindStateUpdates() {
        microphoneService.$inputVolume
            .combineLatest(microphoneService.$isMuted)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusButton()
            }
            .store(in: &cancellables)
    }

    @objc
    private func handleStatusItemClick() {
        guard let button = statusItem?.button else { return }
        guard let event = NSApp.currentEvent else { return }
        let eventType = event.type
        let isCtrlLeftClick = eventType == .leftMouseUp && event.modifierFlags.contains(.control)

        if eventType == .rightMouseDown || isCtrlLeftClick {
            popover.performClose(nil)
            microphoneService.toggleMute()
            updateStatusButton()
            return
        }

        guard eventType == .leftMouseUp else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }

        let level = microphoneService.isMuted ? 0.0 : min(1, max(0, Double(microphoneService.inputVolume)))
        let base = statusSymbolImage(level: level)
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = (base.withSymbolConfiguration(sizeConfig) ?? base)
        image.isTemplate = true

        button.image = image
        button.title = ""
        button.imagePosition = .imageOnly
        button.contentTintColor = nil
        button.toolTip = statusItemToolTip
    }

    private var volumePercent: Int {
        Int((microphoneService.inputVolume * 100).rounded())
    }

    private var statusItemToolTip: String {
        if microphoneService.isMuted {
            return "Microphone muted — Left: open panel · Right: unmute"
        }
        return "Microphone \(volumePercent)% — Left: open panel · Right: mute/unmute"
    }

    private func statusSymbolImage(level: Double) -> NSImage {
        let symbolName = microphoneService.isMuted
            ? "mic.slash.and.signal.meter.fill"
            : "mic.and.signal.meter.fill"
        let image = NSImage(
            systemSymbolName: symbolName,
            variableValue: level,
            accessibilityDescription: "Microphone"
        )
        if let image {
            return image
        }

        // Fallback for systems that may not have slash+meter symbol.
        return NSImage(
            systemSymbolName: "mic.and.signal.meter.fill",
            variableValue: level,
            accessibilityDescription: "Microphone"
        ) ?? NSImage()
    }

}
