// ============================================================================
// ResultView.swift - Shows AI result with clear "copied to clipboard" feedback
// ============================================================================

import SwiftUI

struct ResultView: View {
    let original: String
    let actionName: String
    let result: String
    let onCopy: () -> Void
    let onBack: () -> Void

    @State private var showCopiedBanner = false
    @State private var hasCopied = false

    var body: some View {
        VStack(spacing: 0) {
            // Green "Copied to clipboard" banner - always visible after copy
            HStack(spacing: 6) {
                Image(systemName: hasCopied ? "checkmark.circle.fill" : "circle.dotted")
                    .foregroundStyle(.white)
                Text(hasCopied ? "Copied to clipboard!" : "Processing...")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(actionName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(hasCopied ? Color.green : Color.gray)

            // Original text (before)
            VStack(alignment: .leading, spacing: 2) {
                Text("BEFORE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                ScrollView {
                    Text(original)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
            }
            .padding(10)
            .background(Color.red.opacity(0.04))

            Divider()

            // Result text (after) - prominent
            VStack(alignment: .leading, spacing: 2) {
                Text("AFTER")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)

                ScrollView {
                    Text(result)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
            }
            .padding(10)
            .background(Color.green.opacity(0.04))

            Divider()

            // Buttons
            HStack {
                Button(action: onBack) {
                    Label("New action", systemImage: "arrow.left")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    onCopy()
                    flashCopied()
                }) {
                    Label(showCopiedBanner ? "Copied!" : "Copy again", systemImage: showCopiedBanner ? "checkmark" : "doc.on.doc")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onAppear {
            // Auto-copy result to clipboard
            onCopy()
            hasCopied = true
        }
    }

    private func flashCopied() {
        showCopiedBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedBanner = false
        }
    }
}
