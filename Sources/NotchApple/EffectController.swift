import AppKit
import QuartzCore

/// Fullscreen click-through overlay: golden flash, pulsing potion vignette,
/// and Minecraft-style pixel particles rising from the bottom of the screen.
final class EffectController {
    private var windows: [NSWindow] = []
    private var active = false

    func runPotionEffect(duration: TimeInterval = 6) {
        guard !active else { return }
        active = true

        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame,
                                  styleMask: .borderless,
                                  backing: .buffered,
                                  defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .screenSaver
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

            let view = EffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
            window.contentView = view
            window.orderFrontRegardless()
            view.start(duration: duration)
            windows.append(window)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) { [weak self] in
            guard let self else { return }
            self.windows.forEach { $0.orderOut(nil) }
            self.windows.removeAll()
            self.active = false
        }
    }
}

final class EffectView: NSView {
    private static let swirlMap = [
        ".XXX.",
        "X....",
        "X.XX.",
        "X..X.",
        ".XX..",
    ]
    private static let sparkleMap = [
        "..X..",
        "..X..",
        "XXXXX",
        "..X..",
        "..X..",
    ]
    private static let white: [Character: (CGFloat, CGFloat, CGFloat)] = ["X": (1, 1, 1)]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func start(duration: TimeInterval) {
        guard let layer else { return }

        // Golden flash — the "gulp" moment.
        let flash = CALayer()
        flash.frame = bounds
        flash.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.22).cgColor
        layer.addSublayer(flash)
        let flashFade = CABasicAnimation(keyPath: "opacity")
        flashFade.fromValue = 1
        flashFade.toValue = 0
        flashFade.duration = 0.8
        flashFade.isRemovedOnCompletion = false
        flashFade.fillMode = .forwards
        flash.add(flashFade, forKey: "fade")

        // Purple vignette pulsing at the screen edges, with a settle-in zoom
        // for a cheap "your FOV just changed" feel.
        let vignette = CAGradientLayer()
        vignette.type = .radial
        vignette.frame = bounds
        vignette.colors = [
            NSColor.clear.cgColor,
            NSColor.clear.cgColor,
            NSColor.systemPurple.withAlphaComponent(0.35).cgColor,
        ]
        vignette.locations = [0, 0.6, 1]
        vignette.startPoint = CGPoint(x: 0.5, y: 0.5)
        vignette.endPoint = CGPoint(x: 1.1, y: 1.1)
        vignette.opacity = 0.6
        layer.addSublayer(vignette)

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.25
        pulse.toValue = 0.9
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = Float(duration / 1.8)
        vignette.add(pulse, forKey: "pulse")

        let zoom = CABasicAnimation(keyPath: "transform.scale")
        zoom.fromValue = 1.2
        zoom.toValue = 1.0
        zoom.duration = 0.9
        zoom.timingFunction = CAMediaTimingFunction(name: .easeOut)
        vignette.add(zoom, forKey: "zoom")

        // Potion particles rising from the bottom edge.
        guard let swirl = PixelArt.image(map: Self.swirlMap, palette: Self.white, scale: 3),
              let sparkle = PixelArt.image(map: Self.sparkleMap, palette: Self.white, scale: 3) else {
            return
        }
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: bounds.width * 0.95, height: 1)
        emitter.emitterCells = [
            makeCell(image: swirl, color: .systemPurple, birthRate: 30, velocity: 110),
            makeCell(image: swirl, color: .systemPink, birthRate: 18, velocity: 90),
            makeCell(image: sparkle, color: .systemYellow, birthRate: 20, velocity: 130),
            makeCell(image: sparkle, color: .white, birthRate: 8, velocity: 150),
        ]
        layer.addSublayer(emitter)

        // Stop emitting early so stragglers fade out before the window closes.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration - 2.0) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration - 0.6) { [weak self] in
            self?.animator().alphaValue = 0
        }
    }

    private func makeCell(image: CGImage,
                          color: NSColor,
                          birthRate: Float,
                          velocity: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = image
        cell.color = color.cgColor
        cell.birthRate = birthRate
        cell.lifetime = 3.5
        cell.lifetimeRange = 1.2
        cell.velocity = velocity
        cell.velocityRange = velocity * 0.5
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = .pi / 7
        cell.yAcceleration = 25
        cell.scale = 1.6
        cell.scaleRange = 0.9
        cell.scaleSpeed = -0.15
        cell.alphaSpeed = -0.3
        cell.spin = 1.5
        cell.spinRange = 3
        return cell
    }
}
