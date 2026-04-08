import Foundation

enum TokenEstimator {
    static func estimate(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    static func isTooLong(_ text: String) -> Bool {
        estimate(text) > 3000
    }

    static func label(_ text: String) -> String {
        let estimate = estimate(text)
        return estimate > 3000 ? "~\(estimate) tokens, likely too long" : "~\(estimate) tokens"
    }
}
