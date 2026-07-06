import AppKit

enum NotchGeometry {
    /// The notch rect in global screen coordinates. Screens without a hardware
    /// notch (external monitors) get a fake one so the app stays testable.
    static func notchRect(on screen: NSScreen) -> NSRect {
        let topInset = screen.safeAreaInsets.top
        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           right.minX > left.maxX {
            return NSRect(x: left.maxX,
                          y: screen.frame.maxY - topInset,
                          width: right.minX - left.maxX,
                          height: topInset)
        }
        let width: CGFloat = 200
        let height: CGFloat = 32
        return NSRect(x: screen.frame.midX - width / 2,
                      y: screen.frame.maxY - height,
                      width: width,
                      height: height)
    }

    /// Prefer the built-in (notched) display.
    static func targetScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
    }
}
