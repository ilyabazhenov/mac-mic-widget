import AppKit
import SwiftUI

struct FloatingHUDScreenGeometry: Equatable {
    let frame: NSRect
    let visibleFrame: NSRect
    let isBuiltIn: Bool

    init(frame: NSRect, visibleFrame: NSRect, isBuiltIn: Bool = false) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.isBuiltIn = isBuiltIn
    }
}

enum FloatingHUDScreenSelectionLogic {
    static func visibleFrame(
        for mode: VisualFeedbackScreenMode,
        screens: [FloatingHUDScreenGeometry],
        mainScreen: FloatingHUDScreenGeometry?,
        mouseLocation: NSPoint
    ) -> NSRect? {
        let preferredMainVisibleFrame = screens.first { $0.isBuiltIn }?.visibleFrame
            ?? mainScreen?.visibleFrame
            ?? screens.first?.visibleFrame

        switch mode {
        case .main:
            return preferredMainVisibleFrame
        case .active:
            return screens.first { $0.frame.contains(mouseLocation) }?.visibleFrame
                ?? preferredMainVisibleFrame
        }
    }
}

@MainActor
final class FloatingHUDController {
    private let localizationService: LocalizationService
    private let visualFeedbackService: VisualFeedbackService
    private let displayDuration: TimeInterval
    private let panelSize = NSSize(width: 280, height: 56)
    private var hideTimer: Timer?
    private var panel: NSPanel?
    private var hostingController: NSHostingController<FloatingHUDView>?

    init(
        localizationService: LocalizationService,
        visualFeedbackService: VisualFeedbackService,
        displayDuration: TimeInterval = 1.2
    ) {
        self.localizationService = localizationService
        self.visualFeedbackService = visualFeedbackService
        self.displayDuration = displayDuration
    }

    func show(state: MicrophoneFeedbackState) {
        present(state: state)
        restartHideTimer()
    }

    func showPersistent(state: MicrophoneFeedbackState) {
        present(state: state)
        hideTimer?.invalidate()
        hideTimer = nil
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        panel?.orderOut(nil)
    }

    private func present(state: MicrophoneFeedbackState) {
        let panel = makePanelIfNeeded(with: state)
        if let hostingController {
            hostingController.rootView = FloatingHUDView(state: state, localizationService: localizationService)
        }
        // Ensure first presentation uses final geometry, not pre-layout defaults.
        panel.setContentSize(panelSize)
        panel.contentView?.layoutSubtreeIfNeeded()
        position(panel: panel)
        panel.orderFrontRegardless()
    }

    private func makePanelIfNeeded(with state: MicrophoneFeedbackState) -> NSPanel {
        if let panel {
            return panel
        }

        let contentRect = NSRect(origin: .zero, size: panelSize)
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let hostingController = NSHostingController(
            rootView: FloatingHUDView(state: state, localizationService: localizationService)
        )
        panel.contentViewController = hostingController

        self.hostingController = hostingController
        self.panel = panel
        return panel
    }

    private func position(panel: NSPanel) {
        let screens = NSScreen.screens.map {
            FloatingHUDScreenGeometry(
                frame: $0.frame,
                visibleFrame: $0.visibleFrame,
                isBuiltIn: Self.isBuiltInDisplay($0)
            )
        }
        let mainScreen = (NSScreen.main ?? NSScreen.screens.first).map {
            FloatingHUDScreenGeometry(
                frame: $0.frame,
                visibleFrame: $0.visibleFrame,
                isBuiltIn: Self.isBuiltInDisplay($0)
            )
        }
        guard let visibleFrame = FloatingHUDScreenSelectionLogic.visibleFrame(
            for: visualFeedbackService.screenMode,
            screens: screens,
            mainScreen: mainScreen,
            mouseLocation: NSEvent.mouseLocation
        ) else { return }
        let frameSize = panel.frame.size
        let width = frameSize.width > 0 ? frameSize.width : panelSize.width
        let height = frameSize.height > 0 ? frameSize.height : panelSize.height
        let x = visibleFrame.midX - (width / 2)
        let y = visibleFrame.maxY - height - 36
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private static func isBuiltInDisplay(_ screen: NSScreen) -> Bool {
        guard
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            return false
        }

        return CGDisplayIsBuiltin(CGDirectDisplayID(screenNumber.uint32Value)) != 0
    }

    private func restartHideTimer() {
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: displayDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer
    }
}
