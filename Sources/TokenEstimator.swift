// ============================================================================
// TokenEstimator.swift - Rough token count estimate for clipboard text
// ============================================================================

import Foundation

enum TokenEstimator {
    /// Rough estimate: ~4 characters per token for English text.
    /// Not exact, but good enough to warn users before they hit the 4096 limit.
    static func estimate(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    /// Whether the text is likely too long for the 4096 context window.
    /// Reserves ~1000 tokens for system prompt + response.
    static func isTooLong(_ text: String) -> Bool {
        estimate(text) > 3000
    }

    /// Human-readable token estimate.
    static func label(_ text: String) -> String {
        let tokens = estimate(text)
        if tokens > 3000 {
            return "~\(tokens) tokens (too long)"
        }
        return "~\(tokens) tokens"
    }
}
