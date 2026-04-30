import SwiftUI
import Foundation
import AppKit
import Combine

@main
struct MicWidgetApp: App {
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
        button.imagePosition = .imageLeading
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

        let symbolName = microphoneService.isMuted ? "mic.slash.fill" : "mic.fill"
        let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Microphone") ?? NSImage()
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [iconNSColor])
        let image = (base.withSymbolConfiguration(sizeConfig.applying(colorConfig)) ?? base)
        image.isTemplate = false

        button.image = image
        button.title = " \(formattedVolumePercent)"
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.toolTip = "Left click: open panel. Right click: mute/unmute."
    }

    private var volumePercent: Int {
        Int((microphoneService.inputVolume * 100).rounded())
    }

    private var formattedVolumePercent: String {
        "\(volumePercent)%"
    }

    private var iconNSColor: NSColor {
        if microphoneService.isMuted { return .secondaryLabelColor }
        if volumePercent < 30 { return .systemRed }
        if volumePercent <= 60 { return .systemYellow }
        return .systemGreen
    }
}
