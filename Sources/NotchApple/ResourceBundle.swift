import Foundation

extension Bundle {
    /// Resolves the app's resource bundle in a way that works both for `swift run`
    /// and for the packaged `.app`.
    ///
    /// SwiftPM's generated `Bundle.module` accessor for an executable target only
    /// looks at `Bundle.main.bundleURL/<name>.bundle`. Inside a real `.app`,
    /// `Bundle.main.bundleURL` is the app root, so the resources would have to sit
    /// there — but anything outside `Contents/` breaks the code signature. Instead
    /// we look for the resource bundle inside `Contents/Resources` (via
    /// `Bundle.main`), and only fall back to `Bundle.module` for the dev layout.
    static let resources: Bundle = {
        if let url = Bundle.main.url(forResource: "NotchApple_NotchApple", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return .module
    }()
}
