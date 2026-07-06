import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notchController = NotchController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        MinecraftTheme.registerFont()
        notchController.start()
    }
}
