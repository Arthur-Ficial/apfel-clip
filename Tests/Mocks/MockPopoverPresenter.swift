import Foundation
@testable import apfel_clip

@MainActor
final class MockPopoverPresenter: PopoverPresenting {
    var showCount = 0
    var hideCount = 0

    func showPopover() {
        showCount += 1
    }

    func hidePopover() {
        hideCount += 1
    }
}
