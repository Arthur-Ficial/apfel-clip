// ============================================================================
// PopoverView.swift - Main popover layout
// ============================================================================

import SwiftUI

enum PopoverState {
    case idle
    case ready(text: String, type: ContentType)
    case loading(action: String)
    case result(original: String, action: String, result: String)
    case customPrompt(text: String)
    case history
}

@MainActor
struct PopoverView: View {
    @Bindable var clipboard: ClipboardMonitor
    @Bindable var runner: ActionRunner
    @Bindable var historyStore: HistoryStore
    @State private var state: PopoverState = .idle
    @State private var customPromptText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.secondary)
                Text("apfel-clip")
                    .font(.headline)
                Spacer()
                Button(action: { state = .history }) {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("History")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            // Content
            switch state {
            case .idle:
                idleView

            case .ready(let text, let type):
                ActionListView(
                    text: text,
                    contentType: type,
                    onAction: { action in
                        Task { await runAction(action, text: text) }
                    },
                    onCustom: {
                        state = .customPrompt(text: text)
                    }
                )

            case .loading(let action):
                loadingView(action: action)

            case .result(let original, let action, let result):
                ResultView(
                    original: original,
                    actionName: action,
                    result: result,
                    onCopy: { copyResult(result) },
                    onBack: { refreshFromClipboard() }
                )

            case .customPrompt(let text):
                customPromptView(text: text)

            case .history:
                HistoryView(
                    store: historyStore,
                    onSelect: { entry in
                        copyResult(entry.result)
                    },
                    onBack: { refreshFromClipboard() }
                )
            }
        }
        .frame(width: 320)
        .onAppear { refreshFromClipboard() }
        .onChange(of: clipboard.currentText) { _, _ in
            refreshFromClipboard()
        }
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 20))
                .foregroundStyle(.quaternary)
            Text("Copy some text to get started")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func loadingView(action: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(action)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func customPromptView(text: String) -> some View {
        VStack(spacing: 10) {
            Text("Custom instruction")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("e.g. Translate to pirate speak", text: $customPromptText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    guard !customPromptText.isEmpty else { return }
                    Task { await runCustom(prompt: customPromptText, text: text) }
                }

            HStack {
                Button("Cancel") { refreshFromClipboard() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Run") {
                    guard !customPromptText.isEmpty else { return }
                    Task { await runCustom(prompt: customPromptText, text: text) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(customPromptText.isEmpty)
            }
        }
        .padding(12)
    }

    // MARK: - Logic

    private func refreshFromClipboard() {
        clipboard.hasNewContent = false
        if let text = clipboard.currentText, !text.isEmpty {
            let type = ContentDetector.detect(text)
            state = .ready(text: text, type: type)
        } else {
            state = .idle
        }
    }

    private func runAction(_ action: ClipAction, text: String) async {
        state = .loading(action: action.name)
        if let result = await runner.run(action: action, text: text) {
            historyStore.add(original: text, action: action.name, result: result)
            state = .result(original: text, action: action.name, result: result)
        } else {
            state = .result(
                original: text,
                action: action.name,
                result: "Error: \(runner.lastError ?? "Unknown error")"
            )
        }
    }

    private func runCustom(prompt: String, text: String) async {
        state = .loading(action: "Custom: \(prompt)")
        if let result = await runner.runCustom(prompt: prompt, text: text) {
            historyStore.add(original: text, action: "Custom", result: result)
            state = .result(original: text, action: "Custom", result: result)
        } else {
            state = .result(
                original: text,
                action: "Custom",
                result: "Error: \(runner.lastError ?? "Unknown error")"
            )
        }
        customPromptText = ""
    }

    private func copyResult(_ text: String) {
        clipboard.copyToClipboard(text)
    }
}
