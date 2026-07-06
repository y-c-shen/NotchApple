import AppKit

/// Read-only "how it works" window, same dirt-panel style as Settings.
final class InfoWindowController {
    static let shared = InfoWindowController()
    private var window: NSWindow?

    private let sections: [(String, String)] = [
        ("How to use",
         "Hover the notch, then press and hold the golden apple to eat it. " +
         "A ring fills as you hold; let go early to cancel."),
        ("\u{2726}  Particles",
         "Pure fun. Eating the apple bursts Minecraft potion particles across " +
         "your whole screen with a golden flash."),
        ("\u{23F1}  Pomodoro",
         "Eat the apple to start a focus timer (set the length with - / +). " +
         "A potion-effect badge counts down in the notch. When it ends you get " +
         "the achievement sound and an \u{201C}Advancement Made!\u{201D} toast."),
        ("\u{26D4}  Blocker",
         "Cold-turkey for distracting sites. While active, opening a blocked " +
         "site drops you on a Minecraft \u{201C}Connection Lost\u{201D} screen. " +
         "Eat the apple again to reconnect. Edit the site list in Settings."),
        ("Tips",
         "Click \u{201C}Mode\u{201D} to switch modes. Right-click the tray for " +
         "quick actions and Quit. Everything is remembered between launches."),
    ]

    func show() {
        if window == nil { build() }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let size = NSSize(width: 500, height: 500)
        let window = MCKeyWindow(contentRect: NSRect(origin: .zero, size: size),
                                 styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        let root = SettingsBackgroundView(frame: NSRect(origin: .zero, size: size))

        let title = NSTextField(labelWithString: "Notch Apple")
        title.font = MinecraftTheme.font(ofSize: 18)
        title.textColor = NSColor(red: 1.0, green: 0.83, blue: 0.25, alpha: 1)
        title.alignment = .center
        title.frame = NSRect(x: 0, y: size.height - 46, width: size.width, height: 26)
        root.addSubview(title)

        var y = size.height - 84
        for (heading, body) in sections {
            let head = NSTextField(labelWithString: heading)
            head.font = MinecraftTheme.font(ofSize: 13)
            head.textColor = .white
            head.frame = NSRect(x: 32, y: y, width: size.width - 64, height: 18)
            root.addSubview(head)
            y -= 20

            let text = NSTextField(wrappingLabelWithString: body)
            text.font = MinecraftTheme.font(ofSize: 11)
            text.textColor = NSColor(white: 0.82, alpha: 1)
            text.isSelectable = false
            text.frame = NSRect(x: 32, y: y - 34, width: size.width - 64, height: 46)
            root.addSubview(text)
            y -= 60
        }

        let done = MCButton(title: "Close",
                            frame: NSRect(x: size.width / 2 - 90, y: 22, width: 180, height: 30))
        done.fontSize = 12
        done.action = { [weak self] in self?.window?.orderOut(nil) }
        root.addSubview(done)

        window.contentView = root
        self.window = window
    }
}
