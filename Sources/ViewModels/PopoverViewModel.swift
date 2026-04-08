import Foundation
import Observation

enum MoveDirection: Sendable { case up, down }

@MainActor
@Observable
final class PopoverViewModel {
    private let actionExecutor: any ClipActionExecuting
    private let clipboardService: any ClipboardService
    private let historyStore: any ClipHistoryStoring
    private let settingsStore: any ClipSettingsStoring
    private let launchAtLoginController: any LaunchAtLoginControlling

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
    var isSaveFormVisible: Bool = false
    var isSaveResultFormVisible: Bool = false
    var editingSavedActionID: String? = nil
    var serverState: ClipServerState = .starting
    var controlPort: Int?
    private var bannerDismissTask: Task<Void, Never>?

    init(
        actionExecutor: any ClipActionExecuting,
        clipboardService: any ClipboardService,
        historyStore: any ClipHistoryStoring,
        settingsStore: any ClipSettingsStoring,
        launchAtLoginController: any LaunchAtLoginControlling
    ) {
        self.actionExecutor = actionExecutor
        self.clipboardService = clipboardService
        self.historyStore = historyStore
        self.settingsStore = settingsStore
        self.launchAtLoginController = launchAtLoginController
    }

    var availableActions: [ClipAction] {
        let hidden = Set(settings.hiddenActionIDs)
        let favorites = Set(settings.favoriteActionIDs)
        let orderedFavorites = settings.favoriteActionIDs
        let builtIn = ClipActionCatalog.actions(for: contentType).filter { !hidden.contains($0.id) }
        let saved = settings.savedCustomActions
            .filter { $0.contentTypes.contains(contentType) && !hidden.contains($0.id) }
            .map { $0.asClipAction() }
        let combined = saved + builtIn  // saved custom actions first by default
        let order = settings.actionOrder

        return combined.sorted { lhs, rhs in
            let lhsFavorite = favorites.contains(lhs.id)
            let rhsFavorite = favorites.contains(rhs.id)
            if lhsFavorite != rhsFavorite { return lhsFavorite && !rhsFavorite }
            if lhsFavorite, rhsFavorite {
                return favoriteRank(of: lhs.id, in: orderedFavorites) < favoriteRank(of: rhs.id, in: orderedFavorites)
            }
            // Respect user drag-order (non-favorites only)
            let lhsPos = order.firstIndex(of: lhs.id)
            let rhsPos = order.firstIndex(of: rhs.id)
            if let l = lhsPos, let r = rhsPos { return l < r }
            if lhsPos != nil { return true }
            if rhsPos != nil { return false }
            // Default: saved before built-in, then catalog rank
            let lhsIsBuiltIn = ClipActionCatalog.action(id: lhs.id) != nil
            let rhsIsBuiltIn = ClipActionCatalog.action(id: rhs.id) != nil
            if lhsIsBuiltIn != rhsIsBuiltIn { return !lhsIsBuiltIn }
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

    /// Seeds the clipboard with a welcome example when the user has never used the app
    /// (no history) and the clipboard is currently empty. Safe to call on every launch.
    func seedWelcomeClipboardIfNeeded() {
        guard history.isEmpty && clipboardText.isEmpty else { return }
        setClipboardText("apfel-clip example — Copy any text, code, or error message. Press \u{2318}\u{21E7}V and pick an action: Fix Grammar, Summarise, Explain Code, and more. On-device AI, no API keys needed.")
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
        isSaveFormVisible = false
        isSaveResultFormVisible = false
        editingSavedActionID = nil
        screen = settings.preferredPanel.screen
    }

    func navigateTo(_ target: ClipScreen) {
        screen = target
        if target == .actions { banner = nil }
    }

    func runAction(id: String) async throws -> ClipResultState {
        if let action = ClipActionCatalog.action(id: id) {
            return try await runAction(action)
        }
        if let saved = settings.savedCustomActions.first(where: { $0.id == id }) {
            return try await runAction(saved.asClipAction())
        }
        throw ClipAppError.actionNotFound(id)
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
                fromHistory: false,
                sourcePrompt: effectivePrompt
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
        showBanner(ClipBanner(style: .success, title: "Copied to clipboard", detail: result.actionName))
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
        showBanner(ClipBanner(style: .info, title: "History cleared", detail: nil, autoDismiss: true))
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

    func saveCustomAction(name: String, icon: String, prompt: String, contentTypes: Set<ContentType>) async {
        let trimName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        let trimPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimName.isEmpty, !trimPrompt.isEmpty, !contentTypes.isEmpty else { return }
        let action = SavedCustomAction(
            id: "saved-\(UUID().uuidString)",
            name: trimName,
            icon: icon,
            prompt: trimPrompt,
            contentTypes: contentTypes,
            createdAt: Date()
        )
        settings.savedCustomActions.insert(action, at: 0)
        await persistSettings()
    }

    func updateSavedAction(_ id: String, name: String, icon: String, contentTypes: Set<ContentType>) async {
        guard let i = settings.savedCustomActions.firstIndex(where: { $0.id == id }) else { return }
        let trimName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimName.isEmpty, !contentTypes.isEmpty else { return }
        settings.savedCustomActions[i].name = trimName
        settings.savedCustomActions[i].icon = icon
        settings.savedCustomActions[i].contentTypes = contentTypes
        await persistSettings()
    }

    func deleteSavedAction(_ id: String) async {
        settings.savedCustomActions.removeAll { $0.id == id }
        settings.favoriteActionIDs.removeAll { $0 == id }
        settings.hiddenActionIDs.removeAll { $0 == id }
        await persistSettings()
    }

    func moveSavedAction(_ id: String, direction: MoveDirection) async {
        guard let i = settings.savedCustomActions.firstIndex(where: { $0.id == id }) else { return }
        let target = direction == .up ? i - 1 : i + 1
        guard settings.savedCustomActions.indices.contains(target) else { return }
        settings.savedCustomActions.swapAt(i, target)
        await persistSettings()
    }

    func reorderAction(_ id: String, before targetID: String) async {
        var order = availableActions.map(\.id)
        guard let from = order.firstIndex(of: id),
              let to = order.firstIndex(of: targetID),
              from != to else { return }
        order.remove(at: from)
        let insertAt = order.firstIndex(of: targetID) ?? to
        order.insert(id, at: insertAt)
        settings.actionOrder = order
        await persistSettings()
    }

    func generateActionName(for prompt: String) async -> String? {
        let instruction = "Suggest a short action name (2–4 words) for a clipboard transformation that does: \(prompt.prefix(300)). Output ONLY the name — no explanation, no quotes, no trailing punctuation."
        return try? await actionExecutor.runCustom(prompt: instruction, input: "")
    }

    func updateAutoCopy(_ enabled: Bool) async {
        settings.autoCopy = enabled
        await persistSettings()
    }

    func updateLaunchAtLogin(_ enabled: Bool) async {
        let previous = settings.launchAtLoginEnabled
        settings.launchAtLoginEnabled = enabled
        settings.launchAtLoginPromptShown = true

        do {
            try launchAtLoginController.setEnabled(enabled)
            await persistSettings()
            showBanner(
                ClipBanner(
                    style: .success,
                    title: enabled ? "Starts at login" : "Launch at login disabled",
                    detail: enabled ? "apfel-clip will open when you sign in." : nil,
                    autoDismiss: true
                )
            )
        } catch {
            settings.launchAtLoginEnabled = previous
            await persistSettings()
            showBanner(
                ClipBanner(
                    style: .error,
                    title: "Launch at login failed",
                    detail: error.localizedDescription
                )
            )
        }
    }

    func applySavedLaunchAtLoginPreference() async {
        guard settings.launchAtLoginPromptShown else { return }

        do {
            try launchAtLoginController.setEnabled(settings.launchAtLoginEnabled)
        } catch {
            showBanner(
                ClipBanner(
                    style: .error,
                    title: "Launch at login failed",
                    detail: error.localizedDescription
                )
            )
        }
    }

    func completeLaunchAtLoginPrompt(enable: Bool) async {
        settings.launchAtLoginPromptShown = true
        await updateLaunchAtLogin(enable)
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
        bannerDismissTask?.cancel()
        self.banner = banner
        guard let banner, banner.style == .success || banner.autoDismiss else { return }
        bannerDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.banner = nil
        }
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
                showBanner(ClipBanner(style: .info, title: "Clipboard updated", detail: "Custom prompt will apply to the latest clipboard text.", autoDismiss: true))
            }
        }
    }

    private func handleSuccessfulRun(
        actionID: String,
        actionName: String,
        input: String,
        output: String,
        fromHistory: Bool,
        sourcePrompt: String? = nil
    ) async -> ClipResultState {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldCopy = settings.autoCopy
        let newResult = ClipResultState(
            actionID: actionID,
            actionName: actionName,
            input: input,
            output: trimmedOutput,
            copiedToClipboard: shouldCopy,
            createdFromHistory: fromHistory,
            sourcePrompt: sourcePrompt
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
            showBanner(ClipBanner(style: .success, title: "Copied to clipboard", detail: actionName))
        } else {
            showBanner(ClipBanner(style: .success, title: "Result ready", detail: actionName))
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
        let catalogValid = Set(ClipActionCatalog.all.map(\.id))
        let savedValid = Set(settings.savedCustomActions.map(\.id))
        let valid = catalogValid.union(savedValid)
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
