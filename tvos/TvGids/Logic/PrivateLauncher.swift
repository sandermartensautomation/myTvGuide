import Foundation
import ObjectiveC

/// Opent een app op bundle-ID via de privé-API `LSApplicationWorkspace`. Nodig voor VRT MAX, dat op tvOS
/// geen URL-scheme heeft. Werkt voor eigen (Xcode-)installaties; een App Store-build wordt hierop afgekeurd.
@MainActor
enum PrivateLauncher {
    static func open(bundleID: String) -> Bool {
        guard let cls = objc_getClass("LSApplicationWorkspace") as? NSObject else { return false }
        let defaultSel = NSSelectorFromString("defaultWorkspace")
        guard cls.responds(to: defaultSel),
              let ws = cls.perform(defaultSel)?.takeUnretainedValue() as? NSObject else { return false }
        let sel = NSSelectorFromString("openApplicationWithBundleID:")
        guard ws.responds(to: sel), let imp = ws.method(for: sel) else { return false }
        typealias Fn = @convention(c) (AnyObject, Selector, NSString) -> Bool
        return unsafeBitCast(imp, to: Fn.self)(ws, sel, bundleID as NSString)
    }
}
