import AppKit
import Foundation

@MainActor
protocol ClipboardService: AnyObject {
    var currentText: String? { get }
    var isCurrentClipboardSensitive: Bool { get }
    /// System-wide, monotonic pasteboard change counter. Survives *this* app's
    /// restarts (it lives in the pasteboard server), so it lets us remember that
    /// a specific clipboard payload was sensitive even after source-app
    /// provenance is lost across a relaunch.
    var currentChangeCount: Int { get }
    var currentSourceAppBundleIdentifier: String? { get }
    var currentSourceAppName: String? { get }
    var onExternalChange: ((String?) -> Void)? { get set }

    func start()
    func stop()
    func refreshNow()
    func setText(_ text: String)
}
