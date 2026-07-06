import AppKit
import Network

/// Cold-turkey-lite: polls the frontmost tab of running browsers once a second
/// via AppleScript and redirects blocked sites to the local "Connection Lost"
/// page. No extension needed; macOS asks once per browser for automation
/// permission the first time.
final class DistractionBlocker {
    private(set) var isActive = false

    private var timer: Timer?
    private let server = DisconnectServer()
    private var inFlight = false

    private struct Browser {
        let bundleID: String
        let appName: String
        let isSafari: Bool
    }

    private static let browsers = [
        Browser(bundleID: "com.apple.Safari", appName: "Safari", isSafari: true),
        Browser(bundleID: "com.google.Chrome", appName: "Google Chrome", isSafari: false),
        Browser(bundleID: "company.thebrowser.Browser", appName: "Arc", isSafari: false),
        Browser(bundleID: "com.brave.Browser", appName: "Brave Browser", isSafari: false),
        Browser(bundleID: "com.microsoft.edgemac", appName: "Microsoft Edge", isSafari: false),
    ]

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            server.start()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.poll()
            }
        } else {
            timer?.invalidate()
            timer = nil
            server.stop()
        }
    }

    private func poll() {
        guard !inFlight else { return }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        let targets = Self.browsers.filter { running.contains($0.bundleID) }
        guard !targets.isEmpty else { return }
        inFlight = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            defer { DispatchQueue.main.async { self?.inFlight = false } }
            for browser in targets {
                self?.check(browser)
            }
        }
    }

    private func check(_ browser: Browser) {
        let getScript: String
        if browser.isSafari {
            getScript = """
            tell application "Safari"
                if (count of windows) > 0 then
                    return URL of front document
                end if
            end tell
            """
        } else {
            getScript = """
            tell application "\(browser.appName)"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """
        }
        guard let urlString = runAppleScript(getScript), isBlocked(urlString) else { return }

        let redirect = "http://127.0.0.1:\(DisconnectServer.port)/"
        let setScript: String
        if browser.isSafari {
            setScript = "tell application \"Safari\" to set URL of front document to \"\(redirect)\""
        } else {
            setScript = "tell application \"\(browser.appName)\" to set URL of active tab of front window to \"\(redirect)\""
        }
        _ = runAppleScript(setScript)
    }

    private func isBlocked(_ urlString: String) -> Bool {
        guard let host = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines))?.host?.lowercased() else {
            return false
        }
        return AppState.shared.blockedDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private func runAppleScript(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Tiny HTTP server on the Minecraft port serving the "Connection Lost" page.
final class DisconnectServer {
    static let port: UInt16 = 25565
    private var listener: NWListener?

    func start() {
        guard listener == nil,
              let listener = try? NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: Self.port)!) else {
            return
        }
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global())
            self?.serve(connection)
        }
        listener.start(queue: .global())
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func serve(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, _, _ in
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let body: Data
            let contentType: String
            if request.hasPrefix("GET /dirt.png") {
                body = Self.dirtPNG
                contentType = "image/png"
            } else {
                body = Data(Self.html.utf8)
                contentType = "text/html; charset=utf-8"
            }
            var response = Data("HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
            response.append(body)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private static let dirtPNG: Data = {
        guard let image = MinecraftTheme.dirtImage(width: 64, height: 64, cell: 4, brightness: 0.32) else {
            return Data()
        }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) ?? Data()
    }()

    private static let html = """
    <!doctype html>
    <html><head><meta charset="utf-8"><title>Connection Lost</title><style>
    html,body{height:100%;margin:0}
    body{background:url(/dirt.png);background-size:64px 64px;image-rendering:pixelated;display:flex;flex-direction:column;align-items:center;justify-content:center;font-family:'Courier New',Courier,monospace}
    .title{color:#aaaaaa;font-size:22px;text-shadow:2px 2px #000;margin-bottom:16px}
    .reason{color:#ffffff;font-size:26px;font-weight:bold;text-shadow:2px 2px #000;margin-bottom:36px}
    button{background:#6f6f6f;border:2px solid #000;box-shadow:inset 2px 2px 0 #a8a8a8,inset -2px -2px 0 #4c4c4c;color:#fff;font-family:inherit;font-size:20px;font-weight:bold;text-shadow:2px 2px #3f3f3f;padding:10px 70px;cursor:pointer}
    button:hover{background:#8791b5}
    </style></head>
    <body>
    <div class="title">Connection Lost</div>
    <div class="reason">Disconnected</div>
    <button onclick="if(history.length>2){history.go(-2)}else{location.href='about:blank'}">Back to server list</button>
    </body></html>
    """
}
