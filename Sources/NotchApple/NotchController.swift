import AppKit

/// Owns the notch panel, watches the mouse, and expands/collapses the tray.
final class NotchController {
    private var panel: NotchPanel?
    private var trayView: TrayView?
    private var pollTimer: Timer?
    private var collapseWork: DispatchWorkItem?
    private var notchRect: NSRect = .zero
    private var expanded = false

    func start() {
        rebuild()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.rebuild()
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func rebuild() {
        panel?.orderOut(nil)
        panel = nil
        trayView = nil
        expanded = false

        guard let screen = NotchGeometry.targetScreen() else { return }
        notchRect = NotchGeometry.notchRect(on: screen)

        let trayWidth = max(notchRect.width + 280, 470)
        let trayHeight = notchRect.height + 196
        let frame = NSRect(x: notchRect.midX - trayWidth / 2,
                           y: screen.frame.maxY - trayHeight,
                           width: trayWidth,
                           height: trayHeight)

        let panel = NotchPanel(frame: frame)
        let tray = TrayView(panelFrame: frame, notchRect: notchRect)
        panel.contentView = tray
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()

        self.panel = panel
        self.trayView = tray
    }

    private func tick() {
        guard let panel, let trayView else { return }
        let mouse = NSEvent.mouseLocation
        if expanded {
            let keepZone = panel.frame.insetBy(dx: -8, dy: -8)
            if keepZone.contains(mouse) || trayView.isEating {
                collapseWork?.cancel()
                collapseWork = nil
            } else {
                scheduleCollapse()
            }
        } else {
            // Slightly padded so grazing the notch edge still triggers.
            if notchRect.insetBy(dx: -4, dy: -6).contains(mouse) {
                expand()
            }
        }
    }

    private func expand() {
        expanded = true
        collapseWork?.cancel()
        collapseWork = nil
        panel?.ignoresMouseEvents = false
        trayView?.setExpanded(true)
        SoundPlayer.shared.play("click", volume: 0.15)
    }

    private func scheduleCollapse() {
        guard collapseWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.collapseWork = nil
            self.expanded = false
            self.panel?.ignoresMouseEvents = true
            self.trayView?.setExpanded(false)
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}
