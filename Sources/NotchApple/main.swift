import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Accessory: no Dock icon, no menu bar entry — the app lives in the notch.
app.setActivationPolicy(.accessory)
app.run()
