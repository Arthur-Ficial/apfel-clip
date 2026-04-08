import Foundation
import Observation

@MainActor
@Observable
final class PopoverViewModel {
    private let actionExecutor: any ClipActionExecuting
    private let clipboardService: any ClipboardService
    private let historyStore: any ClipHistoryStoring
    private let settingsStore: any ClipSettingsStoring

    var screen: ClipScreen = .actions
    var clipboardText: String = ""
    var contentType: ContentType = .text
    var history: [ClipHistoryEntry] = []
    var settings: ClipSettings = ClipSettings()
    var customPrompt: String = ""
    var result: ClipResultState?
    var banner: ClipBanner?
    var isRunning = false
    var runningActionID: String?
    var serverState: ClipServerState = .starting
    var controlPort: Int?

    init(
        actionExecutor: any ClipActionExecuting,
        clipboardService: any ClipboardService,
        historyStore: any ClipHistoryStoring,
        settingsStore: any ClipSettingsStoring
    ) {
        self.actionExecutor = actionExecutor
        self.clipboardService = clipboardService
        self.historyStore = historyStore
        self.settingsStore = settingsStore
    }

    var availableActions: [ClipAction] {
        let hidden = Set(settings.hiddenActionIDs)
        let favorites = Set(settings.favoriteActionIDs)
        let orderedFavorites = settings.favoriteActionIDs
        let base = ClipActionCatalog.actions(for: contentType).filter { !hidden.contains($0.id) }

        return base.sorted { lhs, rhs in
            let lhsFavorite = favorites.contains(lhs.id)
            let rhsFavorite = favorites.contains(rhs.id)
            if lhsFavorite != rhsFavorite {
                return lhsFavorite && !rhsFavorite
            }
            if lhsFavorite, rhsFavorite {
                return favoriteRank(of: lhs.id, in: orderedFavorites) < favoriteRank(of: rhs.id, in: orderedFavorites)
            }
            return catalogRank(of: lhs.id) < catalogRank(of: rhs.id)
        }
    }

    var allActions: [ClipAction] {
        ClipActionCatalog.all
    }

    var tokenEstimateLabel: String {
        guard !clipboardText.isEmpty else { return "" }
        return TokenEstimator.label(clipboardText)
    }

    var clipboardIsTooLong: Bool {
        !clipboardText.isEmpty && TokenEstimator.isTooLong(clipboardText)
    }

    var screenTitle: String {
        switch screen {
        case .actions:
            return "Actions"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        case .customPrompt:
            return "Custom Prompt"
        case .result:
            return "Result"
        }
    }

    var serverStatusTitle: String {
        switch serverState {
        case .starting:
            return "Starting"
        case .ready:
            return "Ready"
        case .failed:
            return "Setup Needed"
        }
    }

    var serverStatusDetail: String {
        switch serverState {
        case .starting:
            return "Launching on-device AI"
        case .ready:
            return "Copy text, code, JSON, or logs to transform them."
        case .failed(let message):
            return message
        }
    }

    var placeholderPreview: String {
        "Copy text, code, JSON, or an error to unlock tailored actions."
    }

    func loadPersistedState() async {
        history = (try? await historyStore.load()) ?? []
        settings = await settingsStore.load()
        screen = settings.preferredPanel.screen
    }

    func attachClipboardListener() {
        clipboardService.onExternalChange = { [weak self] _ in
            self?.handleExternalClipboardChange()
        }
    }

    func refreshFromClipboard() {
        let text = clipboardService.currentText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        clipboardText = text
        contentType = text.isEmpty ? .text : ContentDetector.detect(text)

        if screen == .actions || screen == .customPrompt {
            if text.isEmpty {
                result = nil
            }
        }
    }

    func setClipboardText(_ text: String) {
        clipboardService.setText(text)
        refreshFromClipboard()
    }

    func selectPrimaryPanel(_ panel: ClipPrimaryPanel) async {
        settings.preferredPanel = panel
        await persistSettings()
        screen = panel.screen
        if panel == .actions {
            banner = nil
        }
    }

    func openCustomPrompt() {
        customPrompt = ""
        screen = .customPrompt
    }

    func returnToPrimaryPanel() {
        screen = settings.preferredPanel.screen
    }

    func navigateTo(_ target: ClipScreen) {
        screen = target
        if target == .actions { banner = nil }
    }

    func runAction(id: String) async throws -> ClipResultState {
        guard let action = ClipActionCatalog.action(id: id) else {
            throw ClipAppError.actionNotFound(id)
        }
        return try await runAction(action)
    }

    func runAction(_ action: ClipAction) async throws -> ClipResultState {
        guard !isRunning else {
            throw ClipAppError.alreadyRunning
        }
        guard !clipboardText.isEmpty else {
            throw ClipAppError.missingClipboardText
        }

        isRunning = true
        runningActionID = action.id
        banner = ClipBanner(style: .info, title: "Running \(action.name)", detail: "Applying the action to your clipboard text.")
        defer {
            isRunning = false
            runningActionID = nil
        }

        do {
            let output = try await actionExecutor.run(action: action, input: clipboardText)
            let state = await handleSuccessfulRun(
                actionID: action.id,
                actionName: action.name,
                input: clipboardText,
                output: output,
                fromHistory: false
            )
            return state
        } catch {
            banner = ClipBanner(style: .error, title: "Action failed", detail: error.localizedDescription)
            throw error
        }
    }

    func runCustomPrompt(_ prompt: String? = nil) async throws -> ClipResultState {
        guard !isRunning else {
            throw ClipAppError.alreadyRunning
        }
        guard !clipboardText.isEmpty else {
            throw ClipAppError.missingClipboardText
        }

        let effectivePrompt = (prompt ?? customPrompt).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !effectivePrompt.isEmpty else {
            throw ClipAppError.missingPrompt
        }

        isRunning = true
        runningActionID = "custom"
        banner = ClipBanner(style: .info, title: "Running custom prompt", detail: effectivePrompt)
        defer {
            isRunning = false
            runningActionID = nil
        }

        do {
            let output = try await actionExecutor.runCustom(prompt: effectivePrompt, input: clipboardText)
            await rememberCustomPrompt(effectivePrompt)
            let state = await handleSuccessfulRun(
                actionID: "custom",
                actionName: "Custom Prompt",
                input: clipboardText,
                output: output,
                fromHistory: false
            )
            customPrompt = ""
            return state
        } catch {
            banner = ClipBanner(style: .error, title: "Custom prompt failed", detail: error.localizedDescription)
            throw error
        }
    }

    func copyCurrentResult() {
        guard let result else { return }
        clipboardService.setText(result.output)
        clipboardText = result.output
        contentType = ContentDetector.detect(result.output)
        self.result?.copiedToClipboard = true
        banner = ClipBanner(style: .success, title: "Copied to clipboard", detail: result.actionName)
    }

    func openHistoryEntry(_ entry: ClipHistoryEntry) {
        result = ClipResultState(
            actionID: entry.actionID,
            actionName: entry.actionName,
            input: entry.input,
            output: entry.output,
            copiedToClipboard: false,
            createdFromHistory: true
        )
        banner = nil
        screen = .result
    }

    func clearHistory() async {
        history = []
        try? await historyStore.save([])
        banner = ClipBanner(style: .info, title: "History cleared", detail: nil)
        if screen == .history {
            screen = .history
        }
    }

    func applySettings(
        autoCopy: Bool?,
        preferredPanel: ClipPrimaryPanel?,
        recentCustomPrompts: [String]?,
        favoriteActionIDs: [String]? = nil,
        hiddenActionIDs: [String]? = nil
    ) async {
        if let autoCopy {
            settings.autoCopy = autoCopy
        }
        if let preferredPanel {
            settings.preferredPanel = preferredPanel
            if screen.isPrimaryPanel {
                screen = preferredPanel.screen
            }
        }
        if let recentCustomPrompts {
            settings.recentCustomPrompts = sanitizeRecentPrompts(recentCustomPrompts)
        }
        if let favoriteActionIDs {
            let sanitizedFavoriteActionIDs = sanitizeActionIDs(favoriteActionIDs)
            settings.favoriteActionIDs = sanitizedFavoriteActionIDs
            settings.hiddenActionIDs.removeAll { sanitizedFavoriteActionIDs.contains($0) }
        }
        if let hiddenActionIDs {
            let sanitizedHiddenActionIDs = sanitizeActionIDs(hiddenActionIDs)
            settings.hiddenActionIDs = sanitizedHiddenActionIDs
            settings.favoriteActionIDs.removeAll { sanitizedHiddenActionIDs.contains($0) }
        }
        await settingsStore.save(settings)
    }

    func updateAutoCopy(_ enabled: Bool) async {
        settings.autoCopy = enabled
        await persistSettings()
    }

    func useRecentPrompt(_ prompt: String) {
        customPrompt = prompt
    }

    func setServerState(_ state: ClipServerState) {
        serverState = state
    }

    func setControlPort(_ port: Int?) {
        controlPort = port
    }

    func showBanner(_ banner: ClipBanner?) {
        self.banner = banner
    }

    func isFavorite(_ actionID: String) -> Bool {
        settings.favoriteActionIDs.contains(actionID)
    }

    func isHidden(_ actionID: String) -> Bool {
        settings.hiddenActionIDs.contains(actionID)
    }

    func toggleFavorite(_ actionID: String) async {
        if let index = settings.favoriteActionIDs.firstIndex(of: actionID) {
            settings.favoriteActionIDs.remove(at: index)
        } else {
            settings.favoriteActionIDs.insert(actionID, at: 0)
            settings.hiddenActionIDs.removeAll { $0 == actionID }
        }
        await persistSettings()
    }

    func toggleHidden(_ actionID: String) async {
        if let index = settings.hiddenActionIDs.firstIndex(of: actionID) {
            settings.hiddenActionIDs.remove(at: index)
        } else {
            settings.hiddenActionIDs.insert(actionID, at: 0)
            settings.favoriteActionIDs.removeAll { $0 == actionID }
        }
        await persistSettings()
    }

    private func handleExternalClipboardChange() {
        refreshFromClipboard()
        if screen == .result {
            // New external content arrived — stale result is no longer relevant; go home
            result = nil
            screen = settings.preferredPanel.screen
            banner = nil
        } else if screen == .actions || screen == .customPrompt {
            result = nil
            if !clipboardText.isEmpty && screen == .customPrompt {
                banner = ClipBanner(style: .info, title: "Clipboard updated", detail: "Custom prompt will apply to the latest clipboard text.")
            }
        }
    }

    private func handleSuccessfulRun(
        actionID: String,
        actionName: String,
        input: String,
        output: String,
        fromHistory: Bool
    ) async -> ClipResultState {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldCopy = settings.autoCopy
        let newResult = ClipResultState(
            actionID: actionID,
            actionName: actionName,
            input: input,
            output: trimmedOutput,
            copiedToClipboard: shouldCopy,
            createdFromHistory: fromHistory
        )
        result = newResult
        screen = .result

        let entry = ClipHistoryEntry(
            actionID: actionID,
            actionName: actionName,
            input: input,
            output: trimmedOutput
        )
        history.insert(entry, at: 0)
        history = Array(history.prefix(50))
        try? await historyStore.save(history)

        if shouldCopy {
            clipboardService.setText(trimmedOutput)
            clipboardText = trimmedOutput
            contentType = ContentDetector.detect(trimmedOutput)
            banner = ClipBanner(style: .success, title: "Copied to clipboard", detail: actionName)
        } else {
            banner = ClipBanner(style: .success, title: "Result ready", detail: actionName)
        }

        return newResult
    }

    private func rememberCustomPrompt(_ prompt: String) async {
        settings.recentCustomPrompts.removeAll { $0.caseInsensitiveCompare(prompt) == .orderedSame }
        settings.recentCustomPrompts.insert(prompt, at: 0)
        settings.recentCustomPrompts = Array(settings.recentCustomPrompts.prefix(6))
        await persistSettings()
    }

    private func sanitizeRecentPrompts(_ prompts: [String]) -> [String] {
        var deduped: [String] = []
        for prompt in prompts.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !prompt.isEmpty {
            if !deduped.contains(where: { $0.caseInsensitiveCompare(prompt) == .orderedSame }) {
                deduped.append(prompt)
            }
        }
        return Array(deduped.prefix(6))
    }

    private func sanitizeActionIDs(_ actionIDs: [String]) -> [String] {
        let valid = Set(ClipActionCatalog.all.map(\.id))
        var deduped: [String] = []
        for actionID in actionIDs where valid.contains(actionID) && !deduped.contains(actionID) {
            deduped.append(actionID)
        }
        return deduped
    }

    private func favoriteRank(of actionID: String, in orderedFavorites: [String]) -> Int {
        orderedFavorites.firstIndex(of: actionID) ?? .max
    }

    private func catalogRank(of actionID: String) -> Int {
        ClipActionCatalog.all.firstIndex(where: { $0.id == actionID }) ?? .max
    }

    private func persistSettings() async {
        await settingsStore.save(settings)
    }
}
