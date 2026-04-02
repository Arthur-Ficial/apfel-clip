// ============================================================================
// ActionListView.swift - Grid of available actions for clipboard content
// ============================================================================

import SwiftUI

struct ActionListView: View {
    let text: String
    let contentType: ContentType
    let onAction: (ClipAction) -> Void
    let onCustom: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Clipboard preview
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(contentType.rawValue, systemImage: contentType.icon)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    Spacer()

                    Text(TokenEstimator.label(text))
                        .font(.caption)
                        .foregroundStyle(TokenEstimator.isTooLong(text) ? Color.red : Color.secondary)
                }

                ScrollView {
                    Text(text)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
            }
            .padding(10)
            .background(Color(.textBackgroundColor).opacity(0.5))

            // Token warning
            if TokenEstimator.isTooLong(text) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Text may exceed the 4096 token limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.06))
            }

            Divider()

            // Actions list
            ScrollView {
                VStack(spacing: 2) {
                    let actions = Actions.forType(contentType)
                    ForEach(actions) { action in
                        ActionRow(action: action) {
                            onAction(action)
                        }
                    }

                    Divider()
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)

                    ActionRow(
                        action: ClipAction(
                            "custom",
                            name: "Custom prompt...",
                            icon: "pencil.line",
                            system: "",
                            instruction: "",
                            types: []
                        )
                    ) {
                        onCustom()
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 320)
        }
    }
}

struct ActionRow: View {
    let action: ClipAction
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: action.icon)
                    .frame(width: 18)
                    .foregroundStyle(isHovered ? Color.accentColor : .secondary)
                Text(action.name)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isHovered ? Color.accentColor.opacity(0.08) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { isHovered = $0 }
    }
}
