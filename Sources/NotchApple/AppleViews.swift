import AppKit
import AVFoundation
import QuartzCore

/// The apple plus the press-and-hold eating interaction.
final class AppleContainerView: NSView {
    var onEaten: (() -> Void)?
    private(set) var isHolding = false

    private let holdDuration: TimeInterval = 1.55
    private var holdTimer: Timer?
    private let ring = CAShapeLayer()
    private var appleView: NSView = NSView()
    private var videoView: VideoAppleView?
    private let crumbEmitter = CAEmitterLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        let inset = bounds.insetBy(dx: 7, dy: 7)
        if let video = VideoAppleView.make(frame: inset) {
            appleView = video
            videoView = video
        } else {
            appleView = PixelAppleView(frame: inset)
        }
        appleView.wantsLayer = true
        addSubview(appleView)

        ring.path = CGPath(ellipseIn: bounds.insetBy(dx: 1.5, dy: 1.5), transform: nil)
        ring.fillColor = NSColor.clear.cgColor
        ring.strokeColor = NSColor.systemYellow.cgColor
        ring.lineWidth = 2.5
        ring.lineCap = .round
        ring.strokeEnd = 0
        ring.frame = bounds
        layer?.addSublayer(ring)

        // Minecraft food crumbs: chunky gold/brown pixel cubes that spray off
        // the apple while it's being eaten.
        crumbEmitter.frame = bounds
        crumbEmitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        crumbEmitter.emitterSize = CGSize(width: bounds.width * 0.5, height: bounds.height * 0.5)
        crumbEmitter.emitterShape = .rectangle
        crumbEmitter.birthRate = 0
        crumbEmitter.emitterCells = Self.crumbCells()
        layer?.addSublayer(crumbEmitter)
    }

    private static func crumbCells() -> [CAEmitterCell] {
        let colors: [(CGFloat, CGFloat, CGFloat)] = [
            (0.98, 0.80, 0.20), (0.85, 0.58, 0.12), (0.62, 0.40, 0.10),
        ]
        return colors.map { rgb in
            let cube = PixelArt.image(map: ["XX", "XX"],
                                      palette: ["X": rgb], scale: 3)
            let cell = CAEmitterCell()
            cell.contents = cube
            cell.birthRate = 10
            cell.lifetime = 0.7
            cell.lifetimeRange = 0.3
            cell.velocity = 55
            cell.velocityRange = 30
            cell.emissionRange = .pi * 2
            cell.yAcceleration = -260   // fall downward (flipped layer space)
            cell.scale = 1.0
            cell.scaleRange = 0.5
            cell.spin = 4
            cell.spinRange = 6
            cell.alphaSpeed = -1.2
            return cell
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setActive(_ active: Bool) {
        videoView?.setPlaying(active)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        beginHold()
    }

    override func mouseUp(with event: NSEvent) {
        if isHolding { cancelHold() }
    }

    private func beginHold() {
        guard !isHolding else { return }
        isHolding = true
        SoundPlayer.shared.play("eat", volume: 0.35)
        crumbEmitter.beginTime = CACurrentMediaTime()
        crumbEmitter.birthRate = 1

        centerAnchor(appleView)
        let wobble = CAKeyframeAnimation(keyPath: "transform.scale")
        wobble.values = [1.0, 0.88, 1.04, 0.86, 1.02, 0.9]
        wobble.duration = 0.35
        wobble.repeatCount = .infinity
        appleView.layer?.add(wobble, forKey: "eat")

        ring.removeAllAnimations()
        let progress = CABasicAnimation(keyPath: "strokeEnd")
        progress.fromValue = 0
        progress.toValue = 1
        progress.duration = holdDuration
        ring.strokeEnd = 1
        ring.add(progress, forKey: "progress")

        holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { [weak self] _ in
            self?.completeHold()
        }
    }

    private func cancelHold() {
        isHolding = false
        SoundPlayer.shared.stop("eat")
        crumbEmitter.birthRate = 0
        holdTimer?.invalidate()
        holdTimer = nil
        appleView.layer?.removeAnimation(forKey: "eat")
        ring.removeAllAnimations()
        ring.strokeEnd = 0
    }

    private func completeHold() {
        isHolding = false
        holdTimer = nil
        SoundPlayer.shared.stop("eat")
        SoundPlayer.shared.play("eaten", volume: 0.7)

        // One last burst of crumbs, then stop emitting.
        crumbEmitter.birthRate = 6
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.crumbEmitter.birthRate = 0
        }

        appleView.layer?.removeAnimation(forKey: "eat")
        ring.removeAllAnimations()
        ring.strokeEnd = 0
        onEaten?()

        // Vanish, then respawn with a little pop.
        centerAnchor(appleView)
        let respawn = CAKeyframeAnimation(keyPath: "transform.scale")
        respawn.values = [0.0, 0.0, 1.15, 1.0]
        respawn.keyTimes = [0, 0.55, 0.85, 1]
        respawn.duration = 1.2
        appleView.layer?.add(respawn, forKey: "respawn")
    }

    private func centerAnchor(_ view: NSView) {
        guard let layer = view.layer else { return }
        let frame = view.frame
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: frame.midX, y: frame.midY)
    }
}

/// Plays the chroma-keyed golden apple loop (ProRes 4444 with alpha).
final class VideoAppleView: NSView {
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private let playerLayer = AVPlayerLayer()

    static func make(frame: NSRect) -> VideoAppleView? {
        guard let url = Bundle.resources.url(forResource: "golden_apple", withExtension: "mov") else {
            return nil
        }
        return VideoAppleView(frame: frame, url: url)
    }

    private init(frame frameRect: NSRect, url: URL) {
        super.init(frame: frameRect)
        wantsLayer = true

        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setPlaying(_ playing: Bool) {
        playing ? player.play() : player.pause()
    }
}

/// Fallback if the video resource is missing: hand-drawn 16x16 golden apple.
final class PixelAppleView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.contents = PixelArt.goldenApple()
        layer?.magnificationFilter = .nearest
        layer?.contentsGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

enum PixelArt {
    private static let goldenAppleMap = [
        "................",
        "........bb......",
        ".......bb.......",
        ".......b........",
        "...gggg..gggg...",
        "..gwwggggggggg..",
        ".gwwggggggggggg.",
        ".ggggggggggggdg.",
        ".gggggggggggggd.",
        ".gggggggggggggd.",
        "..gggggggggggd..",
        "...gggggggggg...",
        "....ggg..ggg....",
        "................",
        "................",
        "................",
    ]

    private static let goldenApplePalette: [Character: (CGFloat, CGFloat, CGFloat)] = [
        "g": (0.99, 0.84, 0.10),
        "w": (1.00, 0.97, 0.75),
        "d": (0.72, 0.53, 0.04),
        "b": (0.42, 0.26, 0.13),
    ]

    static func goldenApple(scale: Int = 1) -> CGImage? {
        image(map: goldenAppleMap, palette: goldenApplePalette, scale: scale)
    }

    /// Rasterize a string map into a CGImage, one filled square per character.
    static func image(map: [String],
                      palette: [Character: (CGFloat, CGFloat, CGFloat)],
                      scale: Int = 1) -> CGImage? {
        guard let first = map.first else { return nil }
        let rows = map.count
        let cols = first.count
        guard let context = CGContext(data: nil,
                                      width: cols * scale,
                                      height: rows * scale,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        for (rowIndex, row) in map.enumerated() {
            for (colIndex, character) in row.enumerated() {
                guard let (r, g, b) = palette[character] else { continue }
                context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
                context.fill(CGRect(x: colIndex * scale,
                                    y: (rows - 1 - rowIndex) * scale,
                                    width: scale,
                                    height: scale))
            }
        }
        return context.makeImage()
    }
}
