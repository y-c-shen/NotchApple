import AppKit

/// Minecraft-options-style settings window. Currently: the blocklist editor.
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private var textView: NSTextView?

    func show() {
        if window == nil { build() }
        textView?.string = AppState.shared.blockedDomains.joined(separator: "\n")
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let size = NSSize(width: 480, height: 440)
        let window = MCKeyWindow(contentRect: NSRect(origin: .zero, size: size),
                                 styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        let root = SettingsBackgroundView(frame: NSRect(origin: .zero, size: size))

        let title = NSTextField(labelWithString: "Options")
        title.font = MinecraftTheme.font(ofSize: 18)
        title.textColor = .white
        title.alignment = .center
        title.frame = NSRect(x: 0, y: size.height - 44, width: size.width, height: 26)
        root.addSubview(title)

        let label = NSTextField(labelWithString: "Blocked sites (one per line):")
        label.font = MinecraftTheme.font(ofSize: 11)
        label.textColor = NSColor(white: 1, alpha: 0.8)
        label.frame = NSRect(x: 40, y: size.height - 76, width: size.width - 80, height: 16)
        root.addSubview(label)

        let scroll = NSScrollView(frame: NSRect(x: 40, y: 96, width: size.width - 80, height: size.height - 184))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        let text = NSTextView(frame: NSRect(origin: .zero, size: scroll.contentSize))
        text.autoresizingMask = [.width]
        text.font = MinecraftTheme.font(ofSize: 13)
        text.textColor = .white
        text.backgroundColor = NSColor(white: 0, alpha: 0.55)
        text.insertionPointColor = .white
        text.isRichText = false
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.textContainerInset = NSSize(width: 8, height: 8)
        scroll.documentView = text
        root.addSubview(scroll)
        textView = text

        let restore = MCButton(title: "Restore Defaults",
                               frame: NSRect(x: size.width / 2 - 188, y: 40, width: 180, height: 30))
        restore.fontSize = 12
        restore.action = { [weak self] in
            self?.textView?.string = AppState.defaultBlockedDomains.joined(separator: "\n")
        }
        root.addSubview(restore)

        let done = MCButton(title: "Done",
                            frame: NSRect(x: size.width / 2 + 8, y: 40, width: 180, height: 30))
        done.fontSize = 12
        done.action = { [weak self] in self?.save() }
        root.addSubview(done)

        window.contentView = root
        self.window = window
    }

    private func save() {
        let domains = (textView?.string ?? "")
            .split(whereSeparator: \.isNewline)
            .map { line -> String in
                var domain = line.trimmingCharacters(in: .whitespaces).lowercased()
                for prefix in ["https://", "http://", "www."] where domain.hasPrefix(prefix) {
                    domain = String(domain.dropFirst(prefix.count))
                }
                if let slash = domain.firstIndex(of: "/") {
                    domain = String(domain[..<slash])
                }
                return domain
            }
            .filter { !$0.isEmpty }
        AppState.shared.blockedDomains = domains
        window?.orderOut(nil)
    }
}

final class MCKeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class SettingsBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        if let dirt = MinecraftTheme.dirtImage(width: Int(frameRect.width),
                                               height: Int(frameRect.height),
                                               cell: 8, brightness: 0.30) {
            layer?.contents = dirt
        }
        layer?.borderColor = NSColor.black.cgColor
        layer?.borderWidth = 3
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
