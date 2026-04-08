import Foundation
@testable import apfel_clip

@MainActor
final class MockLaunchAtLoginController: LaunchAtLoginControlling {
    var isEnabled = false
    var setCalls: [Bool] = []
    var nextError: (any Error)?

    func setEnabled(_ enabled: Bool) throws {
        setCalls.append(enabled)
        if let nextError {
            throw nextError
        }
        isEnabled = enabled
    }
}
