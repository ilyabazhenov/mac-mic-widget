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
    enum StatusItemAction: Equatable {
        case toggleMuteWithoutPopover
        case togglePopover
        case ignore
    }

    enum HUDDisplayMode {
        case transient
        case persistent
    }

    private let microphoneService = MicrophoneService()
    private let launchAtLoginService = LaunchAtLoginService()
    private let visualFeedbackService = VisualFeedbackService()
    private let localizationService = LocalizationService()
    private let holdToUnmuteService = HoldToUnmuteService()
    private lazy var floatingHUDController = FloatingHUDController(localizationService: localizationService)
    private let audioFeedbackService = AudioFeedbackService()
    private lazy var globalHotkeyService = GlobalHotkeyService(
        toggleHandler: { },
        eventHandler: { [weak self] event in
            self?.handleGlobalHotkeyEvent(event)
        }
    )
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private let popoverWidth: CGFloat = 340

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        bindStateUpdates()
        updateStatusButton()
        // Start potentially expensive services after menu bar item is visible.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.microphoneService.start()
            self.launchAtLoginService.refreshStatus()
            self.globalHotkeyService.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        microphoneService.stop()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
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
        popover.contentSize = NSSize(
            width: popoverWidth,
            height: MenuBarTab.defaultTab.preferredPopoverHeight
        )
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(
                microphoneService: microphoneService,
                launchAtLoginService: launchAtLoginService,
                globalHotkeyService: globalHotkeyService,
                visualFeedbackService: visualFeedbackService,
                localizationService: localizationService,
                audioFeedbackService: audioFeedbackService,
                holdToUnmuteService: holdToUnmuteService,
                onToggleMuteFromPopover: { [weak self] in
                    self?.toggleMuteFromPopover()
                },
                onSetInputVolumeFromPopover: { [weak self] volume in
                    self?.setInputVolumeFromPopover(volume)
                },
                onTabChanged: { [weak self] tab in
                    self?.updatePopoverHeight(for: tab)
                }
            )
        )
    }

    private func updatePopoverHeight(for tab: MenuBarTab) {
        popover.contentSize = NSSize(width: popoverWidth, height: tab.preferredPopoverHeight)
    }

    private func bindStateUpdates() {
        microphoneService.$inputVolume
            .combineLatest(microphoneService.$isMuted)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusButton()
            }
            .store(in: &cancellables)

        localizationService.$selectedLanguage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusButton()
            }
            .store(in: &cancellables)

        microphoneService.$lastError
            .dropFirst()
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.audioFeedbackService.playError()
            }
            .store(in: &cancellables)

        globalHotkeyService.$lastError
            .dropFirst()
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.audioFeedbackService.playError()
            }
            .store(in: &cancellables)

        launchAtLoginService.$lastError
            .dropFirst()
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.audioFeedbackService.playError()
            }
            .store(in: &cancellables)

        launchAtLoginService.$needsLoginItemsApproval
            .dropFirst()
            .removeDuplicates()
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.audioFeedbackService.playPermissionNeeded()
            }
            .store(in: &cancellables)
    }

    @objc
    private func handleStatusItemClick() {
        guard let button = statusItem?.button else { return }
        guard let event = NSApp.currentEvent else { return }
        let action = AppDelegate.classifyStatusItemAction(eventType: event.type, modifierFlags: event.modifierFlags)

        if action == .toggleMuteWithoutPopover {
            popover.performClose(nil)
            handleExternalToggle(source: .statusItemSecondaryClick)
            return
        }

        guard action == .togglePopover else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func handleExternalToggle(source: MicrophoneChangeSource) {
        let didToggle = microphoneService.toggleMute()
        handleDidToggle(didToggle, source: source, hudDisplayMode: .transient)
    }

    private func handleDidToggle(
        _ didToggle: Bool,
        source: MicrophoneChangeSource,
        hudDisplayMode: HUDDisplayMode
    ) {
        updateStatusButton()
        guard didToggle else { return }
        let state = makeFeedbackState(source: source)
        if visualFeedbackService.isEnabled {
            switch hudDisplayMode {
            case .transient:
                floatingHUDController.show(state: state)
            case .persistent:
                floatingHUDController.showPersistent(state: state)
            }
        }
        audioFeedbackService.play(for: state)
    }

    private func handleGlobalHotkeyEvent(_ event: GlobalHotkeyEvent) {
        if holdToUnmuteService.isEnabled == false && holdToUnmuteService.isHoldingFromMuted == false {
            guard event == .pressed else { return }
            handleExternalToggle(source: .globalHotkey)
            return
        }

        let didToggle: Bool
        let hudDisplayMode: HUDDisplayMode
        switch event {
        case .pressed:
            didToggle = holdToUnmuteService.handleHotkeyPressed(microphone: microphoneService)
            hudDisplayMode = .persistent
        case .released:
            didToggle = holdToUnmuteService.handleHotkeyReleased(microphone: microphoneService)
            hudDisplayMode = .transient
            if didToggle == false {
                floatingHUDController.hide()
            }
        }
        handleDidToggle(didToggle, source: .globalHotkey, hudDisplayMode: hudDisplayMode)
    }

    private func toggleMuteFromPopover() {
        _ = microphoneService.toggleMute()
        updateStatusButton()
    }

    private func setInputVolumeFromPopover(_ value: Float) {
        microphoneService.setInputVolume(value)
        updateStatusButton()
    }

    static func classifyStatusItemAction(
        eventType: NSEvent.EventType,
        modifierFlags: NSEvent.ModifierFlags
    ) -> StatusItemAction {
        let isCtrlLeftClick = eventType == .leftMouseUp && modifierFlags.contains(.control)
        if eventType == .rightMouseDown || isCtrlLeftClick {
            return .toggleMuteWithoutPopover
        }
        if eventType == .leftMouseUp {
            return .togglePopover
        }
        return .ignore
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }

        let presentation = StatusItemPresentationLogic.makePresentation(
            isMuted: microphoneService.isMuted,
            inputVolume: microphoneService.inputVolume
        )
        let base = statusSymbolImage(presentation: presentation)
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let image = (base.withSymbolConfiguration(sizeConfig) ?? base)
        image.isTemplate = true

        button.image = image
        button.title = ""
        button.imagePosition = .imageOnly
        button.contentTintColor = microphoneService.isMuted
            ? NSColor.systemRed.withAlphaComponent(0.75)
            : nil
        button.toolTip = statusItemToolTip
    }

    private var volumePercent: Int {
        Int((microphoneService.inputVolume * 100).rounded())
    }

    private func makeFeedbackState(source: MicrophoneChangeSource) -> MicrophoneFeedbackState {
        MicrophoneFeedbackState(
            isMuted: microphoneService.isMuted,
            volumePercent: volumePercent,
            triggerSource: source,
            timestamp: Date()
        )
    }

    private var statusItemToolTip: String {
        if microphoneService.isMuted {
            return localizationService.string("tooltip.muted")
        }
        return localizationService.string("tooltip.active", volumePercent)
    }

    private func statusSymbolImage(presentation: StatusItemPresentation) -> NSImage {
        if let variableImage = NSImage(
            systemSymbolName: presentation.symbolName,
            variableValue: presentation.variableValue,
            accessibilityDescription: "Microphone"
        ) {
            return variableImage
        }

        if let fixedImage = NSImage(
            systemSymbolName: presentation.symbolName,
            accessibilityDescription: "Microphone"
        ) {
            return fixedImage
        }

        // Fallback for systems that may not have slash+meter symbol or variable symbols.
        if let fallbackVariableImage = NSImage(
            systemSymbolName: "mic.and.signal.meter.fill",
            variableValue: presentation.variableValue,
            accessibilityDescription: "Microphone"
        ) {
            return fallbackVariableImage
        }

        if let fallbackFixedImage = NSImage(
            systemSymbolName: "mic.and.signal.meter.fill",
            accessibilityDescription: "Microphone"
        ) {
            return fallbackFixedImage
        }

        return NSImage(
            systemSymbolName: "mic.fill",
            accessibilityDescription: "Microphone"
        ) ?? NSImage()
    }

}
