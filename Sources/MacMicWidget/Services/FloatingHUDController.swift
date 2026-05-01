import AppKit
import SwiftUI

@MainActor
final class FloatingHUDController {
    private let localizationService: LocalizationService
    private let displayDuration: TimeInterval
    private let panelSize = NSSize(width: 280, height: 56)
    private var hideTimer: Timer?
    private var panel: NSPanel?
    private var hostingController: NSHostingController<FloatingHUDView>?

    init(localizationService: LocalizationService, displayDuration: TimeInterval = 1.2) {
        self.localizationService = localizationService
        self.displayDuration = displayDuration
    }

    func show(state: MicrophoneFeedbackState) {
        let panel = makePanelIfNeeded(with: state)
        if let hostingController {
            hostingController.rootView = FloatingHUDView(state: state, localizationService: localizationService)
        }
        // Ensure first presentation uses final geometry, not pre-layout defaults.
        panel.setContentSize(panelSize)
        panel.contentView?.layoutSubtreeIfNeeded()
        position(panel: panel)
        panel.orderFrontRegardless()
        restartHideTimer()
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
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        let frameSize = panel.frame.size
        let width = frameSize.width > 0 ? frameSize.width : panelSize.width
        let height = frameSize.height > 0 ? frameSize.height : panelSize.height
        let x = visibleFrame.midX - (width / 2)
        let y = visibleFrame.maxY - height - 36
        panel.setFrameOrigin(NSPoint(x: x, y: y))
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
