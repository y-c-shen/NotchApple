import AppKit
import CoreText

enum MinecraftTheme {
    static func registerFont() {
        guard let url = Bundle.module.url(forResource: "Monocraft", withExtension: "ttc") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func font(ofSize size: CGFloat) -> NSFont {
        NSFont(name: "Monocraft", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .bold)
    }

    /// A real frame of the golden apple (not the flat pixel-art fallback),
    /// used wherever a static apple image is shown (e.g. the toast).
    static let appleStill: NSImage? = {
        guard let url = Bundle.module.url(forResource: "apple_still", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    /// Random-noise dirt tiles, MC options-screen style. brightness < 1 darkens.
    static func dirtImage(width: Int, height: Int, cell: Int, brightness: CGFloat) -> CGImage? {
        guard width > 0, height > 0, cell > 0,
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        let palette: [(CGFloat, CGFloat, CGFloat)] = [
            (0.475, 0.333, 0.227),
            (0.526, 0.376, 0.263),
            (0.396, 0.263, 0.196),
            (0.345, 0.224, 0.153),
            (0.573, 0.424, 0.302),
        ]
        for y in stride(from: 0, to: height, by: cell) {
            for x in stride(from: 0, to: width, by: cell) {
                let (r, g, b) = palette.randomElement()!
                context.setFillColor(CGColor(red: r * brightness, green: g * brightness,
                                             blue: b * brightness, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: cell, height: cell))
            }
        }
        return context.makeImage()
    }

    static let clockIcon: CGImage? = PixelArt.image(map: [
        "..WWWW..",
        ".W....W.",
        "W...Y..W",
        "W...Y..W",
        "W...YY.W",
        "W......W",
        ".W....W.",
        "..WWWW..",
    ], palette: ["W": (0.92, 0.92, 0.92), "Y": (1.0, 0.85, 0.2)], scale: 3)

    static let barrierIcon: CGImage? = PixelArt.image(map: [
        "..RRRR..",
        ".RR...R.",
        "R.RR...R",
        "R..RR..R",
        "R...RR.R",
        "R....RRR",
        ".R....R.",
        "..RRRR..",
    ], palette: ["R": (0.86, 0.16, 0.16)], scale: 3)
}

/// Classic Minecraft options button: black border, gray bevel body,
/// blue-ish tint on hover, white text with a hard shadow.
final class MCButton: NSView {
    var title: String {
        didSet { needsDisplay = true }
    }
    var fontSize: CGFloat = 12
    var action: (() -> Void)?

    private var hovered = false { didSet { needsDisplay = true } }
    private var pressed = false { didSet { needsDisplay = true } }

    init(title: String, frame: NSRect) {
        self.title = title
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false; pressed = false }
    override func mouseDown(with event: NSEvent) { pressed = true }

    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        pressed = false
        if inside {
            SoundPlayer.shared.play("click", volume: 0.5)
            action?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()
        let inner = bounds.insetBy(dx: 1, dy: 1)
        (hovered ? NSColor(red: 0.45, green: 0.51, blue: 0.71, alpha: 1) : NSColor(white: 0.42, alpha: 1)).setFill()
        inner.fill()
        NSColor(white: 1, alpha: 0.3).setFill()
        NSRect(x: inner.minX, y: inner.maxY - 2, width: inner.width, height: 2).fill()
        NSColor(white: 0, alpha: 0.35).setFill()
        NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: 3).fill()

        let font = MinecraftTheme.font(ofSize: fontSize)
        let text = NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: NSColor.white])
        let shadow = NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: NSColor(white: 0.15, alpha: 0.9)])
        let size = text.size()
        // Center on the cap height, not the full line box — Monocraft's line
        // metrics leave extra space below the baseline that skews midY.
        var origin = NSPoint(x: bounds.midX - size.width / 2,
                             y: bounds.midY - font.capHeight / 2 + font.descender)
        if pressed { origin.y -= 1 }
        shadow.draw(at: NSPoint(x: origin.x + 1, y: origin.y - 1))
        text.draw(at: origin)
    }
}

/// Potion-effect HUD square: dark bordered box, pixel icon, timer text below.
final class MCEffectBadge: NSView {
    var text: String = "" {
        didSet { needsDisplay = true }
    }
    private let icon: CGImage?

    init(icon: CGImage?, frame: NSRect) {
        self.icon = icon
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
        NSColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 0.88).setFill()
        path.fill()
        NSColor(white: 0.5, alpha: 0.8).setStroke()
        path.lineWidth = 1
        path.stroke()

        if let icon, let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.interpolationQuality = .none
            context.draw(icon, in: CGRect(x: bounds.midX - 12, y: bounds.maxY - 30, width: 24, height: 24))
            context.restoreGState()
        }

        let string = NSAttributedString(string: text, attributes: [
            .font: MinecraftTheme.font(ofSize: 10),
            .foregroundColor: NSColor.white,
        ])
        let size = string.size()
        string.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: 4))
    }
}

/// "Advancement Made!" toast that drops in under the notch.
enum ToastWindow {
    private static var current: NSPanel?

    static func show(title: String, subtitle: String) {
        DispatchQueue.main.async { showOnMain(title: title, subtitle: subtitle) }
    }

    private static func showOnMain(title: String, subtitle: String) {
        current?.orderOut(nil)
        guard let screen = NotchGeometry.targetScreen() else { return }
        let size = NSSize(width: 320, height: 64)
        let notch = NotchGeometry.notchRect(on: screen)
        let targetFrame = NSRect(x: screen.frame.midX - size.width / 2,
                                 y: screen.frame.maxY - notch.height - size.height - 10,
                                 width: size.width, height: size.height)

        let panel = NSPanel(contentRect: targetFrame.offsetBy(dx: 0, dy: 24),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = ToastView(title: title, subtitle: subtitle,
                                      frame: NSRect(origin: .zero, size: size))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        current = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak panel] in
            guard let panel, panel == current else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                if current == panel { current = nil }
            })
        }
    }
}

final class ToastView: NSView {
    private let title: String
    private let subtitle: String

    init(title: String, subtitle: String, frame: NSRect) {
        self.title = title
        self.subtitle = subtitle
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
        NSColor(white: 0.1, alpha: 0.96).setFill()
        path.fill()
        NSColor(white: 0.45, alpha: 1).setStroke()
        path.lineWidth = 2
        path.stroke()

        if let icon = MinecraftTheme.appleStill {
            NSGraphicsContext.current?.imageInterpolation = .none
            let h: CGFloat = 38
            let w = h * (icon.size.width / max(icon.size.height, 1))
            icon.draw(in: CGRect(x: 16, y: bounds.midY - h / 2, width: w, height: h))
        }

        NSAttributedString(string: title, attributes: [
            .font: MinecraftTheme.font(ofSize: 13),
            .foregroundColor: NSColor(red: 1.0, green: 0.83, blue: 0.25, alpha: 1),
        ]).draw(at: NSPoint(x: 58, y: bounds.midY + 4))
        NSAttributedString(string: subtitle, attributes: [
            .font: MinecraftTheme.font(ofSize: 11),
            .foregroundColor: NSColor.white,
        ]).draw(at: NSPoint(x: 58, y: bounds.midY - 18))
    }
}
