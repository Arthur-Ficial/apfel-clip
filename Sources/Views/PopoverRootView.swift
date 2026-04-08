import SwiftUI

struct PopoverRootView: View {
    @Bindable var viewModel: PopoverViewModel
    @State private var hoveredActionID: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.98, blue: 0.93),
                    Color(red: 0.99, green: 0.97, blue: 0.92),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if let banner = viewModel.banner {
                    bannerView(banner)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                } else {
                    Spacer().frame(height: 12)
                }
                content
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .frame(width: 540, height: 820)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.16, green: 0.49, blue: 0.22))
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text("apfel-clip")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Text(viewModel.serverStatusTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(serverTint)
                    Text(viewModel.serverStatusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if viewModel.screen == .customPrompt {
                    Button {
                        viewModel.returnToPrimaryPanel()
                    } label: {
                        Label("Back", systemImage: "arrow.left")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        Label("⌘⇧V", systemImage: "keyboard")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Button {
                            viewModel.navigateTo(.settings)
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(viewModel.screen == .settings
                                    ? Color(red: 0.16, green: 0.49, blue: 0.22)
                                    : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                screenTab(title: "Action", screen: .actions, selectPanel: .actions)
                screenTab(title: "Result", screen: .result, selectPanel: nil)
                screenTab(title: "History", screen: .history, selectPanel: .history)
            }

            if viewModel.screen == .customPrompt {
                HStack {
                    Text("Custom Prompt")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.screen {
        case .actions:
            actionsPanel
        case .history:
            historyPanel
        case .settings:
            settingsPanel
        case .customPrompt:
            customPromptPanel
        case .result:
            resultPanel
        }
    }

    private var actionsPanel: some View {
        VStack(spacing: 14) {
            previewCard

            if viewModel.clipboardIsTooLong {
                SurfaceCard {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Large clipboard payload")
                                .font(.subheadline.weight(.semibold))
                            Text("The local model may reject input beyond its context window.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            SurfaceCard(fillAvailableHeight: true) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Suggested actions")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Spacer()
                        Button {
                            viewModel.openCustomPrompt()
                        } label: {
                            Label("Custom", systemImage: "wand.and.stars")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(red: 0.15, green: 0.45, blue: 0.20))
                        .disabled(viewModel.clipboardText.isEmpty)
                    }

                    if viewModel.clipboardText.isEmpty {
                        emptyHint(
                            icon: "doc.text.magnifyingglass",
                            title: "Nothing in the clipboard yet",
                            detail: viewModel.placeholderPreview
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(viewModel.availableActions) { action in
                                    actionButton(action)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func actionButton(_ action: ClipAction) -> some View {
        let isThisRunning = viewModel.runningActionID == action.id
        let isOtherRunning = viewModel.isRunning && !isThisRunning
        let isHovered = hoveredActionID == action.id && !viewModel.isRunning
        let green = Color(red: 0.16, green: 0.49, blue: 0.22)
        let bgColor: Color = isThisRunning ? green.opacity(0.07) : isHovered ? .white : Color.white.opacity(0.8)
        let isSaved = viewModel.settings.savedCustomActions.contains { $0.id == action.id }
        let subtitleText = isThisRunning ? "Working…"
            : isSaved ? "Custom"
            : action.localAction == nil ? "AI action" : "Local action"

        return Button {
            Task { _ = try? await viewModel.runAction(action) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if isThisRunning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(green)
                    } else {
                        Image(systemName: action.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(green)
                    }
                }
                .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(isThisRunning ? green : .secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isHovered ? green.opacity(0.5) : Color.secondary.opacity(0.5))
                    .opacity(isThisRunning ? 0 : 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bgColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isThisRunning ? green.opacity(0.25) : Color.clear, lineWidth: 1)
            )
            .opacity(isOtherRunning ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isOtherRunning)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRunning)
        .onHover { hovered in
            hoveredActionID = hovered ? action.id : nil
        }
    }

    private var historyPanel: some View {
        VStack(spacing: 14) {
            SurfaceCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent transformations")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("\(viewModel.history.count) saved locally")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Clear") {
                        Task {
                            await viewModel.clearHistory()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(viewModel.history.isEmpty)
                }
            }

            SurfaceCard(fillAvailableHeight: true) {
                if viewModel.history.isEmpty {
                    emptyHint(
                        icon: "clock.arrow.circlepath",
                        title: "No history yet",
                        detail: "Successful actions are stored here so you can reopen or re-copy them."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(viewModel.history) { entry in
                                Button {
                                    viewModel.openHistoryEntry(entry)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(entry.actionName)
                                                .font(.subheadline.weight(.semibold))
                                            Spacer()
                                            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(entry.output)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.white.opacity(0.8))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var settingsPanel: some View {
        VStack(spacing: 14) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { viewModel.settings.autoCopy },
                        set: { enabled in
                            Task {
                                await viewModel.updateAutoCopy(enabled)
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-copy results")
                                .font(.subheadline.weight(.semibold))
                            Text("Write every successful result back to the clipboard immediately.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Preferred home panel")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    HStack(spacing: 8) {
                        ForEach(ClipPrimaryPanel.allCases, id: \.self) { panel in
                            Button {
                                Task {
                                    await viewModel.selectPrimaryPanel(panel)
                                }
                            } label: {
                                Text(panel.title)
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(viewModel.settings.preferredPanel == panel ? Color(red: 0.16, green: 0.49, blue: 0.22) : Color.white.opacity(0.75))
                                    )
                                    .foregroundStyle(viewModel.settings.preferredPanel == panel ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // ── Saved Actions ────────────────────────────────────────────────
            SurfaceCard {
                savedActionsSection
            }

            SurfaceCard(fillAvailableHeight: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent custom prompts")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    if viewModel.settings.recentCustomPrompts.isEmpty {
                        Text("No custom prompts saved yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(viewModel.settings.recentCustomPrompts, id: \.self) { prompt in
                                    Text(prompt)
                                        .font(.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.white.opacity(0.8))
                                        )
                                }
                            }
                        }
                    }

                    Divider()

                    Text("Action manager")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(viewModel.allActions) { action in
                                HStack(spacing: 10) {
                                    Image(systemName: action.icon)
                                        .frame(width: 18)
                                        .foregroundStyle(Color(red: 0.16, green: 0.49, blue: 0.22))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(action.name)
                                            .font(.subheadline.weight(.medium))
                                        Text(action.contentTypes.map(\.rawValue).sorted().joined(separator: " • "))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        Task {
                                            await viewModel.toggleFavorite(action.id)
                                        }
                                    } label: {
                                        Image(systemName: viewModel.isFavorite(action.id) ? "star.fill" : "star")
                                            .foregroundStyle(viewModel.isFavorite(action.id) ? Color.orange : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Favorite action")

                                    Button {
                                        Task {
                                            await viewModel.toggleHidden(action.id)
                                        }
                                    } label: {
                                        Image(systemName: viewModel.isHidden(action.id) ? "eye.slash.fill" : "eye")
                                            .foregroundStyle(viewModel.isHidden(action.id) ? Color.red : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Hide action")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.78))
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var savedActionsSection: some View {
        let green = Color(red: 0.16, green: 0.49, blue: 0.22)
        let saved = viewModel.settings.savedCustomActions
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Saved Actions")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if !saved.isEmpty {
                    Text("\(saved.count)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(green.opacity(0.12)))
                        .foregroundStyle(green)
                }
                Spacer()
            }

            if saved.isEmpty {
                Text("No saved actions yet. Type a custom prompt and tap \"Save as Action\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 6) {
                    ForEach(saved) { action in
                        savedActionRow(action)
                    }
                }
            }
        }
    }

    private func savedActionRow(_ saved: SavedCustomAction) -> some View {
        let green = Color(red: 0.16, green: 0.49, blue: 0.22)
        let isExpanded = viewModel.editingSavedActionID == saved.id
        return VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: saved.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(saved.name)
                        .font(.subheadline.weight(.medium))
                    Text(saved.contentTypes.map(\.rawValue).sorted().joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.editingSavedActionID = isExpanded ? nil : saved.id
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "pencil")
                        .foregroundStyle(isExpanded ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.runningActionID == saved.id)

                Button {
                    Task { await viewModel.deleteSavedAction(saved.id) }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )

            if isExpanded {
                SavedActionFormView(
                    mode: .edit(action: saved),
                    onSave: { name, icon, types in
                        Task {
                            await viewModel.updateSavedAction(saved.id, name: name, icon: icon, contentTypes: types)
                            withAnimation { viewModel.editingSavedActionID = nil }
                        }
                    },
                    onCancel: {
                        withAnimation { viewModel.editingSavedActionID = nil }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
    }

    private var customPromptPanel: some View {
        VStack(spacing: 14) {
            previewCard

            SurfaceCard(fillAvailableHeight: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prompt")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                    TextEditor(text: $viewModel.customPrompt)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.9))
                        )
                        .frame(height: 130)

                    // Save as Action
                    let promptIsEmpty = viewModel.customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.isSaveFormVisible.toggle()
                            }
                        } label: {
                            Label(
                                viewModel.isSaveFormVisible ? "Cancel" : "Save as Action",
                                systemImage: viewModel.isSaveFormVisible ? "xmark" : "bookmark.badge.plus"
                            )
                            .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(red: 0.15, green: 0.45, blue: 0.20))
                        .disabled(promptIsEmpty)
                    }

                    if viewModel.isSaveFormVisible {
                        SavedActionFormView(
                            mode: .create(prompt: viewModel.customPrompt),
                            onSave: { name, icon, types in
                                Task {
                                    await viewModel.saveCustomAction(
                                        name: name, icon: icon,
                                        prompt: viewModel.customPrompt, contentTypes: types
                                    )
                                    withAnimation { viewModel.isSaveFormVisible = false }
                                    viewModel.showBanner(.init(style: .success, title: "Action saved", detail: name))
                                }
                            },
                            onCancel: {
                                withAnimation { viewModel.isSaveFormVisible = false }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }

                    if !viewModel.settings.recentCustomPrompts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent prompts")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(viewModel.settings.recentCustomPrompts, id: \.self) { prompt in
                                        Button {
                                            viewModel.useRecentPrompt(prompt)
                                        } label: {
                                            Text(prompt)
                                                .font(.caption)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(Color.white.opacity(0.78))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 120)
                        }
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Button("Cancel") {
                            viewModel.returnToPrimaryPanel()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            Task {
                                _ = try? await viewModel.runCustomPrompt()
                            }
                        } label: {
                            Label("Run Prompt", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private var resultPanel: some View {
        VStack(spacing: 10) {
            if let result = viewModel.result {
                // ── Original (compact, on top) ──────────────────────────────
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Original")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(result.input)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.75))
                            .lineLimit(4)
                            .truncationMode(.tail)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // ── Action connector ────────────────────────────────────────
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 1)
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.16, green: 0.49, blue: 0.22))
                        Text(result.actionName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.16, green: 0.49, blue: 0.22))
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.16, green: 0.49, blue: 0.22))
                    }
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 1)
                }
                .padding(.vertical, 2)

                // ── Result (large, primary, fills remaining space) ──────────
                SurfaceCard(fillAvailableHeight: true) {
                    let isInClipboard = viewModel.clipboardText.trimmingCharacters(in: .whitespacesAndNewlines) == result.output
                    let green = Color(red: 0.16, green: 0.49, blue: 0.22)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("Result")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Spacer()
                            if isInClipboard {
                                Label("In clipboard", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(green)
                            }
                            Button {
                                viewModel.copyCurrentResult()
                            } label: {
                                Label(isInClipboard ? "Copy again" : "Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        TextEditor(text: Binding(
                            get: { result.output },
                            set: { viewModel.result?.output = $0 }
                        ))
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.9))
                        )

                        Spacer(minLength: 0)

                        HStack {
                            Button {
                                viewModel.returnToPrimaryPanel()
                            } label: {
                                Label("Back", systemImage: "arrow.left")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                Task { _ = try? await viewModel.runAction(id: result.actionID) }
                            } label: {
                                Label("Run Again", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(result.actionID == "custom")
                        }
                    }
                }
            } else {
                emptyHint(
                    icon: "sparkles.rectangle.stack",
                    title: "No result yet",
                    detail: "Run an action to see its output here."
                )
            }
        }
    }

    private var previewCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(viewModel.contentType.rawValue, systemImage: viewModel.contentType.icon)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.86))
                        .clipShape(Capsule())

                    Spacer()

                    if !viewModel.tokenEstimateLabel.isEmpty {
                        Text(viewModel.tokenEstimateLabel)
                            .font(.caption.monospaced())
                            .foregroundStyle(viewModel.clipboardIsTooLong ? Color.orange : .secondary)
                    }
                }

                ScrollView {
                    Text(viewModel.clipboardText.isEmpty ? viewModel.placeholderPreview : viewModel.clipboardText)
                        .font(viewModel.clipboardText.isEmpty ? .body : .system(.body, design: .monospaced))
                        .foregroundStyle(viewModel.clipboardText.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private func screenTab(title: String, screen: ClipScreen, selectPanel: ClipPrimaryPanel?) -> some View {
        let isActive = viewModel.screen == screen
        let isResultUnavailable = screen == .result && viewModel.result == nil
        let green = Color(red: 0.16, green: 0.49, blue: 0.22)
        return Button {
            if let panel = selectPanel {
                Task { await viewModel.selectPrimaryPanel(panel) }
            } else {
                viewModel.navigateTo(screen)
            }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? green : Color.white.opacity(0.75))
                )
                .foregroundStyle(isActive ? .white : isResultUnavailable ? Color.secondary.opacity(0.5) : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(isResultUnavailable)
    }

    private func bannerView(_ banner: ClipBanner) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: bannerIcon(for: banner.style))
                .foregroundStyle(bannerColor(for: banner.style))
            VStack(alignment: .leading, spacing: 3) {
                Text(banner.title)
                    .font(.subheadline.weight(.semibold))
                if let detail = banner.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
    }

    private func emptyHint(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var serverTint: Color {
        switch viewModel.serverState {
        case .starting:
            return .orange
        case .ready:
            return Color(red: 0.16, green: 0.49, blue: 0.22)
        case .failed:
            return .red
        }
    }

    private func bannerColor(for style: ClipBanner.Style) -> Color {
        switch style {
        case .info:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        }
    }

    private func bannerIcon(for style: ClipBanner.Style) -> String {
        switch style {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}

private struct SurfaceCard<Content: View>: View {
    let fillAvailableHeight: Bool
    @ViewBuilder let content: Content

    init(fillAvailableHeight: Bool = false, @ViewBuilder content: () -> Content) {
        self.fillAvailableHeight = fillAvailableHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: fillAvailableHeight ? .infinity : nil, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}
