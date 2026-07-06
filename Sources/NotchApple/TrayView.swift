import AppKit

/// The dirt-textured tray that grows out of the notch. Contents (apple,
/// buttons, badges) only fade in once the tray has finished expanding, and
/// fade out before it collapses.
final class TrayView: NSView {
    var isEating: Bool { apple.isHolding }

    private let shape = NSView()
    private var apple: AppleContainerView!
    private var modeButton: MCButton!
    private var minusButton: MCButton!
    private var plusButton: MCButton!
    private var pomodoroBadge: MCEffectBadge!
    private var blockerBadge: MCEffectBadge!
    private let timeLabel = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "")
    private let collapsedFrame: NSRect
    private let expandedFrame: NSRect
    private var contentViews: [NSView] = []
    private var refreshTimer: Timer?
    private var isExpanded = false
    private var animationGeneration = 0

    private let expandDuration: TimeInterval = 0.26
    private let fadeDuration: TimeInterval = 0.16

    init(panelFrame: NSRect, notchRect: NSRect) {
        // Collapsed, the shape hides exactly behind the notch (dark on dark).
        collapsedFrame = NSRect(x: notchRect.minX - panelFrame.minX,
                                y: panelFrame.height - notchRect.height,
                                width: notchRect.width,
                                height: notchRect.height)
        expandedFrame = NSRect(origin: .zero, size: panelFrame.size)
        super.init(frame: NSRect(origin: .zero, size: panelFrame.size))
        wantsLayer = true

        shape.wantsLayer = true
        shape.layer?.backgroundColor = NSColor.black.cgColor
        if let dirt = MinecraftTheme.dirtImage(width: Int(panelFrame.width),
                                               height: Int(panelFrame.height),
                                               cell: 10, brightness: 0.16) {
            shape.layer?.contents = dirt
            shape.layer?.contentsGravity = .resizeAspectFill
        }
        shape.layer?.cornerRadius = 14
        shape.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        shape.layer?.masksToBounds = true
        shape.frame = collapsedFrame
        addSubview(shape)

        let width = bounds.width
        let height = bounds.height
        let notchHeight = notchRect.height
        let contentTop = height - notchHeight

        // "hold to eat" sits directly under the notch, above the apple.
        hint.font = MinecraftTheme.font(ofSize: 10)
        hint.textColor = NSColor(white: 1, alpha: 0.7)
        hint.alignment = .center
        hint.frame = NSRect(x: 0, y: contentTop - 16, width: width, height: 14)

        // The apple is the centerpiece.
        let appleSize: CGFloat = 84
        let appleY = contentTop - 18 - appleSize
        apple = AppleContainerView(frame: NSRect(x: width / 2 - appleSize / 2, y: appleY,
                                                 width: appleSize, height: appleSize))
        apple.onEaten = { AppState.shared.handleEat() }

        pomodoroBadge = MCEffectBadge(icon: MinecraftTheme.clockIcon,
                                      frame: NSRect(x: width / 2 - appleSize / 2 - 50,
                                                    y: appleY + 14, width: 42, height: 52))
        blockerBadge = MCEffectBadge(icon: MinecraftTheme.barrierIcon,
                                     frame: NSRect(x: width / 2 + appleSize / 2 + 8,
                                                   y: appleY + 14, width: 42, height: 52))

        let modeY = appleY - 32
        modeButton = MCButton(title: "", frame: NSRect(x: width / 2 - 100, y: modeY, width: 200, height: 24))
        modeButton.action = { [weak self] in
            AppState.shared.cycleMode()
            self?.refresh()
        }

        let rowY = modeY - 26
        minusButton = MCButton(title: "-", frame: NSRect(x: width / 2 - 78, y: rowY, width: 24, height: 20))
        minusButton.action = { [weak self] in
            AppState.shared.pomodoroMinutes -= 5
            self?.refresh()
        }
        plusButton = MCButton(title: "+", frame: NSRect(x: width / 2 + 54, y: rowY, width: 24, height: 20))
        plusButton.action = { [weak self] in
            AppState.shared.pomodoroMinutes += 5
            self?.refresh()
        }
        timeLabel.font = MinecraftTheme.font(ofSize: 11)
        timeLabel.textColor = .white
        timeLabel.alignment = .center
        timeLabel.frame = NSRect(x: width / 2 - 48, y: rowY + 3, width: 96, height: 15)

        let settingsButton = MCButton(title: "Settings",
                                      frame: NSRect(x: width / 2 - 96, y: 8, width: 92, height: 20))
        settingsButton.fontSize = 10
        settingsButton.action = { SettingsWindowController.shared.show() }

        let infoButton = MCButton(title: "Info",
                                  frame: NSRect(x: width / 2 + 4, y: 8, width: 92, height: 20))
        infoButton.fontSize = 10
        infoButton.action = { InfoWindowController.shared.show() }

        contentViews = [hint, apple, pomodoroBadge, blockerBadge, modeButton,
                        minusButton, plusButton, timeLabel, settingsButton, infoButton]
        for view in contentViews {
            view.alphaValue = 0
            view.isHidden = true
            addSubview(view)
        }

        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.isExpanded else { return }
            self.refresh()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func refresh() {
        let state = AppState.shared
        modeButton.title = "Mode: \(state.mode.label)"

        let showsTime = state.mode == .pomodoro
        minusButton.isHidden = !showsTime || !isExpanded
        plusButton.isHidden = !showsTime || !isExpanded
        timeLabel.isHidden = !showsTime || !isExpanded
        timeLabel.stringValue = "\(state.pomodoroMinutes) min"

        pomodoroBadge.isHidden = !state.pomodoro.isActive || !isExpanded
        if state.pomodoro.isActive {
            let total = Int(state.pomodoro.remaining.rounded())
            pomodoroBadge.text = String(format: "%d:%02d", total / 60, total % 60)
        }
        blockerBadge.isHidden = !state.blocker.isActive || !isExpanded
        blockerBadge.text = "\u{221E}"

        switch state.mode {
        case .particles:
            hint.stringValue = "hold to eat"
        case .pomodoro:
            hint.stringValue = state.pomodoro.isActive ? "focusing - hold to restart" : "hold to focus"
        case .blocker:
            hint.stringValue = state.blocker.isActive ? "hold to reconnect" : "hold to block"
        }
    }

    func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded
        animationGeneration += 1
        let generation = animationGeneration
        apple.setActive(expanded)

        if expanded {
            refresh()
            // 1) Grow the tray. 2) Only then reveal its contents.
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = expandDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                shape.animator().frame = expandedFrame
            }, completionHandler: { [weak self] in
                guard let self, generation == self.animationGeneration else { return }
                self.setContentVisible(true)
            })
        } else {
            // 1) Hide contents. 2) Only then shrink the tray.
            setContentVisible(false)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = fadeDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                for view in contentViews { view.animator().alphaValue = 0 }
            }, completionHandler: { [weak self] in
                guard let self, generation == self.animationGeneration else { return }
                for view in self.contentViews { view.isHidden = true }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = self.expandDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    self.shape.animator().frame = self.collapsedFrame
                }
            })
        }
    }

    private func setContentVisible(_ visible: Bool) {
        for view in contentViews { view.isHidden = false }
        refresh() // re-applies per-mode hidden state for badges/time row
        if visible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = fadeDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                for view in contentViews where !view.isHidden {
                    view.animator().alphaValue = 1
                }
            }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let state = AppState.shared
        let menu = NSMenu()
        menu.autoenablesItems = false

        if state.pomodoro.isActive {
            let cancel = NSMenuItem(title: "Cancel Pomodoro", action: #selector(cancelPomodoro), keyEquivalent: "")
            cancel.target = self
            menu.addItem(cancel)
        }
        if state.blocker.isActive {
            let stop = NSMenuItem(title: "Stop Blocking", action: #selector(stopBlocking), keyEquivalent: "")
            stop.target = self
            menu.addItem(stop)
        }
        let names = state.blockedDomains.map { $0.replacingOccurrences(of: ".com", with: "") }
        let summary = names.prefix(6).joined(separator: ", ") + (names.count > 6 ? ", ..." : "")
        let info = NSMenuItem(title: "Blocked: \(summary)", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Notch Apple", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func cancelPomodoro() {
        AppState.shared.pomodoro.cancel()
        refresh()
    }

    @objc private func stopBlocking() {
        AppState.shared.blocker.setActive(false)
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
