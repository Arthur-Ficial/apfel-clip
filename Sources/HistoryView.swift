// ============================================================================
// HistoryView.swift - Recent transformations
// ============================================================================

import SwiftUI
import Observation

struct HistoryEntry: Identifiable {
    let id = UUID()
    let original: String
    let action: String
    let result: String
    let timestamp: Date
}

@MainActor
@Observable
final class HistoryStore {
    var entries: [HistoryEntry] = []

    func add(original: String, action: String, result: String) {
        let entry = HistoryEntry(original: original, action: action, result: result, timestamp: Date())
        entries.insert(entry, at: 0)
        if entries.count > 10 {
            entries.removeLast()
        }
    }
}

struct HistoryView: View {
    let store: HistoryStore
    let onSelect: (HistoryEntry) -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Text("History")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(store.entries.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if store.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundStyle(.quaternary)
                    Text("No history yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(store.entries) { entry in
                            Button(action: { onSelect(entry) }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(entry.action)
                                            .font(.caption.weight(.medium))
                                        Spacer()
                                        Text(timeAgo(entry.timestamp))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Text(entry.result)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}
