import SwiftUI

// MARK: - Icon catalog

enum SavedActionIconCatalog {
    static let `default` = "wand.and.stars"
    static let all: [String] = [
        // Writing
        "pencil", "pencil.and.outline", "square.and.pencil", "text.cursor",
        "textformat", "textformat.abc", "bold", "italic",
        // Transform
        "wand.and.stars", "wand.and.rays", "sparkles", "arrow.2.squarepath",
        "arrow.triangle.2.circlepath", "shuffle", "tornado", "staroflife",
        // Language / Communication
        "globe", "globe.americas.fill", "translate", "character.bubble",
        "quote.bubble", "message", "envelope", "megaphone",
        // Analysis
        "magnifyingglass", "doc.text.magnifyingglass", "checklist", "checkmark.seal",
        "exclamationmark.triangle", "ladybug", "shield", "lock.shield",
        // Code
        "chevron.left.forwardslash.chevron.right", "terminal", "curlybraces", "function",
        "number", "barcode", "qrcode", "cpu",
        // Utility
        "scissors", "scissors.badge.ellipsis", "list.bullet", "list.number",
        "bookmark", "tag", "folder", "doc.on.doc",
    ]
}

// MARK: - Icon grid (used inline when expanded)

private struct IconGridView: View {
    @Binding var selectedIcon: String
    private let green = Color(red: 0.16, green: 0.49, blue: 0.22)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(SavedActionIconCatalog.all, id: \.self) { symbol in
                    iconCell(symbol)
                }
            }
            .padding(4)
        }
        .frame(maxHeight: 188)
    }

    private func iconCell(_ symbol: String) -> some View {
        let isSelected = symbol == selectedIcon
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? green.opacity(0.12) : Color.white.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? green : Color.clear, lineWidth: 1.5)
                )
            Image(systemName: symbol)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? green : Color.primary)
        }
        .frame(width: 36, height: 36)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.12)) { selectedIcon = symbol }
        }
    }
}

// MARK: - Save/edit form

struct SavedActionFormView: View {
    enum Mode {
        case create(prompt: String)
        case edit(action: SavedCustomAction)
    }

    let mode: Mode
    let onSave: (String, String, Set<ContentType>) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedTypes: Set<ContentType>
    @State private var isIconGridVisible = false

    private let green = Color(red: 0.16, green: 0.49, blue: 0.22)

    init(mode: Mode, onSave: @escaping (String, String, Set<ContentType>) -> Void, onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _selectedIcon = State(initialValue: SavedActionIconCatalog.default)
            _selectedTypes = State(initialValue: [.text])
        case .edit(let action):
            _name = State(initialValue: action.name)
            _selectedIcon = State(initialValue: action.icon)
            _selectedTypes = State(initialValue: action.contentTypes)
        }
    }

    private var promptPreview: String {
        switch mode {
        case .create(let prompt): return prompt
        case .edit(let action): return action.prompt
        }
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedTypes.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Prompt preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(promptPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.6))
                    )
            }

            // Icon button + Name field on same row
            HStack(alignment: .bottom, spacing: 10) {
                // Prominent icon button — always visible, tap to toggle grid
                VStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { isIconGridVisible.toggle() }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isIconGridVisible ? green.opacity(0.15) : Color.white.opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(isIconGridVisible ? green : green.opacity(0.25), lineWidth: 1.5)
                                )
                            Image(systemName: selectedIcon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(green)
                        }
                        .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    Text(isIconGridVisible ? "Close" : "Icon")
                        .font(.caption2)
                        .foregroundStyle(green)
                }

                // Name field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Action name")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Translate to Italian", text: $name)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(!name.isEmpty ? green.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                        .frame(height: 36)
                }
            }

            // Icon grid — expands inline on demand
            if isIconGridVisible {
                IconGridView(selectedIcon: $selectedIcon)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Content type toggles
            VStack(alignment: .leading, spacing: 6) {
                Text("Triggers for")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(ContentType.allCases, id: \.self) { type in
                        contentTypeToggle(type)
                    }
                }
            }

            // Buttons
            HStack {
                Button(isEditMode ? "Cancel edit" : "Cancel") { onCancel() }
                    .buttonStyle(.bordered)
                Spacer()
                Button(isEditMode ? "Save changes" : "Save Action") {
                    onSave(name, selectedIcon, selectedTypes)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.94, green: 0.99, blue: 0.94).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(green.opacity(0.22), lineWidth: 1)
        )
    }

    private func contentTypeToggle(_ type: ContentType) -> some View {
        let isSelected = selectedTypes.contains(type)
        return Button {
            withAnimation(.easeInOut(duration: 0.1)) {
                if isSelected { selectedTypes.remove(type) } else { selectedTypes.insert(type) }
            }
        } label: {
            Label(type.rawValue, systemImage: type.icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? green : Color.white.opacity(0.75))
                )
                .foregroundStyle(isSelected ? .white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
