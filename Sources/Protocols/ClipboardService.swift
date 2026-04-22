import AppKit
import Foundation

@MainActor
protocol ClipboardService: AnyObject {
    var currentText: String? { get }
    var isCurrentClipboardSensitive: Bool { get }
    var onExternalChange: ((String?) -> Void)? { get set }

    func start()
    func stop()
    func refreshNow()
    func setText(_ text: String)
}
