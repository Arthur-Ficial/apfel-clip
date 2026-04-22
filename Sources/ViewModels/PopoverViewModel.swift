import AppKit
import Foundation
import Observation

enum MoveDirection: Sendable { case up, down }

struct ClipboardSourceAppOption: Identifiable, Equatable, Sendable {
    let bundleIdentifier: String
    let name: String
    let path: String

    var id: String { bundleIdentifier }
}

@MainActor
@Observable
final class PopoverViewModel {
    typealias InstalledClipboardSourceAppsProvider = @Sendable () -> [ClipboardSourceAppOption]
    typealias ClipboardSourceAppURLResolver = @Sendable (String) -> URL?

    private let actionExecutor: any ClipActionExecuting
    private let clipboardService: any ClipboardService
    private let historyStore: any ClipHistoryStoring
    private let clipboardHistoryStore: any ClipboardHistoryStoring
    private let settingsStore: any ClipSettingsStoring
    private let launchAtLoginController: any LaunchAtLoginControlling
    private let installedClipboardSourceAppsProvider: InstalledClipboardSourceAppsProvider
    private let clipboardSourceAppURLResolver: ClipboardSourceAppURLResolver

    var screen: ClipScreen = .actions
    var clipboardText: String = ""
    var isClipboardContentSensitive = false
    var isClipboardContentIgnoredByApp = false
    var currentClipboardSourceAppBundleIdentifier: String?
    var currentClipboardSourceAppName: String?
    var installedClipboardSourceApps: [ClipboardSourceAppOption] = []
    var isLoadingInstalledClipboardSourceApps = false
    var contentType: ContentType = .text
    var history: [ClipHistoryEntry] = []
    var clipboardHistory: [ClipboardHistoryEntry] = []
    var selectedHistorySection: ClipHistorySection = .transformations
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
    var updateState: UpdateState = .idle
    var isWelcomeVisible: Bool = false
    private var bannerDismissTask: Task<Void, Never>?
    var onHotkeyChanged: ((HotkeyConfig) -> Void)?

    init(
        actionExecutor: any ClipActionExecuting,
        clipboardService: any ClipboardService,
        historyStore: any ClipHistoryStoring,
        clipboardHistoryStore: any ClipboardHistoryStoring,
        settingsStore: any ClipSettingsStoring,
        launchAtLoginController: any LaunchAtLoginControlling,
        installedClipboardSourceAppsProvider: @escaping InstalledClipboardSourceAppsProvider = {
            PopoverViewModel.discoverInstalledClipboardSourceApps()
        },
        clipboardSourceAppURLResolver: @escaping ClipboardSourceAppURLResolver = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }
    ) {
        self.actionExecutor = actionExecutor
        self.clipboardService = clipboardService
        self.historyStore = historyStore
        self.clipboardHistoryStore = clipboardHistoryStore
        self.settingsStore = settingsStore
        self.launchAtLoginController = launchAtLoginController
        self.installedClipboardSourceAppsProvider = installedClipboardSourceAppsProvider
        self.clipboardSourceAppURLResolver = clipboardSourceAppURLResolver
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
        if isClipboardContentSensitive {
            return "Sensitive clipboard content hidden for privacy and excluded from history."
        }
        if isClipboardContentIgnoredByApp {
            return "Clipboard content from an ignored app is hidden and excluded from history."
        }
        return "Copy text, code, JSON, or an error to unlock tailored actions."
    }

    var clipboardEmptyStateTitle: String {
        if isClipboardContentSensitive {
            return "Clipboard content hidden"
        }
        if isClipboardContentIgnoredByApp {
            return "Clipboard ignored"
        }
        return "Nothing in the clipboard yet"
    }

    var clipboardIgnoredAppDisplayName: String? {
        currentClipboardSourceAppName ?? currentClipboardSourceAppBundleIdentifier
    }

    var clipboardIgnoredAppDescription: String {
        if let appName = clipboardIgnoredAppDisplayName {
            return "Clipboard content from \(appName) is hidden and excluded from history."
        }
        return "Clipboard content from an ignored app is hidden and excluded from history."
    }

    var currentClipboardSourceAppOption: ClipboardSourceAppOption? {
        guard let bundleID = currentClipboardSourceAppBundleIdentifier, !bundleID.isEmpty else { return nil }
        return resolveClipboardSourceApp(bundleIdentifier: bundleID, preferredName: currentClipboardSourceAppName)
    }

    var ignoredClipboardSourceApps: [ClipboardSourceAppOption] {
        settings.ignoredClipboardSourceBundleIDs.map {
            resolveClipboardSourceApp(bundleIdentifier: $0, preferredName: nil)
        }
    }

    func loadPersistedState() async {
        settings = await settingsStore.load()
        history = (try? await historyStore.load()) ?? []
        clipboardHistory = (try? await clipboardHistoryStore.load(limit: clipboardHistoryLimit)) ?? []
        screen = settings.preferredPanel.screen
    }

    func attachClipboardListener() {
        clipboardService.onExternalChange = { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.handleExternalClipboardChange()
            }
        }
    }

    func refreshFromClipboard() {
        let rawText = clipboardService.currentText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        currentClipboardSourceAppBundleIdentifier = clipboardService.currentSourceAppBundleIdentifier
        currentClipboardSourceAppName = clipboardService.currentSourceAppName
        isClipboardContentSensitive = clipboardService.isCurrentClipboardSensitive && !rawText.isEmpty
        isClipboardContentIgnoredByApp = shouldIgnoreClipboardSourceApp() && !rawText.isEmpty
        let text = (isClipboardContentSensitive || isClipboardContentIgnoredByApp) ? "" : rawText
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
        let rawClipboardText = clipboardService.currentText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard history.isEmpty && clipboardText.isEmpty && rawClipboardText.isEmpty else { return }
        setClipboardText("apfel-clip example - Copy any text, code, or error message. Press \(settings.hotkey.displayLabel) and pick an action: Fix Grammar, Summarise, Explain Code, and more. On-device AI, no API keys needed.")
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

    func removeHistoryEntry(_ id: String) async {
        let filteredHistory = history.filter { $0.id != id }
        guard filteredHistory.count != history.count else { return }
        history = filteredHistory
        try? await historyStore.save(filteredHistory)
    }

    func clearClipboardHistory() async {
        clipboardHistory = []
        try? await clipboardHistoryStore.save([], limit: clipboardHistoryLimit)
        showBanner(ClipBanner(style: .info, title: "Clipboard history cleared", detail: nil, autoDismiss: true))
    }

    func removeClipboardHistoryEntry(_ id: String) async {
        let filteredHistory = clipboardHistory.filter { $0.id != id }
        guard filteredHistory.count != clipboardHistory.count else { return }
        clipboardHistory = filteredHistory
        try? await clipboardHistoryStore.save(filteredHistory, limit: clipboardHistoryLimit)
    }

    func copyClipboardHistoryEntry(_ entry: ClipboardHistoryEntry) {
        clipboardService.setText(entry.text)
        clipboardText = entry.text
        contentType = entry.contentType
        result = nil
        selectedHistorySection = .clipboard
        screen = .actions
        showBanner(ClipBanner(style: .success, title: "Copied to clipboard", detail: "Clipboard history"))
    }

    func applySettings(
        autoCopy: Bool?,
        preferredPanel: ClipPrimaryPanel?,
        recentCustomPrompts: [String]?,
        favoriteActionIDs: [String]? = nil,
        hiddenActionIDs: [String]? = nil,
        checkForUpdatesOnLaunch: Bool? = nil
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
        if let checkForUpdatesOnLaunch {
            settings.checkForUpdatesOnLaunch = checkForUpdatesOnLaunch
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

    func updateClipboardHistoryLimit(_ value: Int) async {
        settings.clipboardHistoryLimit = ClipSettings.clampClipboardHistoryLimit(value)
        clipboardHistory = Array(clipboardHistory.prefix(clipboardHistoryLimit))
        await persistSettings()
        try? await clipboardHistoryStore.save(clipboardHistory, limit: clipboardHistoryLimit)
    }

    func loadInstalledClipboardSourceAppsIfNeeded(forceReload: Bool = false) async {
        if isLoadingInstalledClipboardSourceApps { return }
        if !forceReload && !installedClipboardSourceApps.isEmpty { return }

        isLoadingInstalledClipboardSourceApps = true
        let appsProvider = self.installedClipboardSourceAppsProvider
        let apps = await Task.detached(priority: .utility) {
            appsProvider()
        }.value
        installedClipboardSourceApps = apps
        isLoadingInstalledClipboardSourceApps = false
    }

    func addIgnoredClipboardSourceBundleID(_ bundleID: String) async {
        settings.ignoredClipboardSourceBundleIDs = ClipSettings.sanitizeBundleIdentifiers(
            settings.ignoredClipboardSourceBundleIDs + [bundleID]
        )
        await persistSettings()
        refreshFromClipboard()
    }

    func addCurrentClipboardSourceAppToIgnoredList() async {
        guard let bundleID = currentClipboardSourceAppBundleIdentifier, !bundleID.isEmpty else { return }
        await addIgnoredClipboardSourceBundleID(bundleID)
    }

    func addIgnoredClipboardSourceApp(_ app: ClipboardSourceAppOption) async {
        await addIgnoredClipboardSourceBundleID(app.bundleIdentifier)
    }

    func removeIgnoredClipboardSourceBundleID(_ bundleID: String) async {
        let updated = settings.ignoredClipboardSourceBundleIDs.filter {
            $0.caseInsensitiveCompare(bundleID) != .orderedSame
        }
        guard updated.count != settings.ignoredClipboardSourceBundleIDs.count else { return }
        settings.ignoredClipboardSourceBundleIDs = updated
        await persistSettings()
        refreshFromClipboard()
    }

    var clipboardHistoryLimit: Int {
        ClipSettings.clampClipboardHistoryLimit(settings.clipboardHistoryLimit)
    }

    var hotkeyDisplayLabel: String {
        settings.hotkey.displayLabel
    }

    func updateHotkey(_ config: HotkeyConfig) async {
        settings.hotkey = config
        await persistSettings()
        onHotkeyChanged?(config)
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

    private func handleExternalClipboardChange() async {
        refreshFromClipboard()
        await recordClipboardHistoryEntryIfNeeded()
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

    private func recordClipboardHistoryEntryIfNeeded() async {
        guard !clipboardText.isEmpty else { return }
        guard !clipboardService.isCurrentClipboardSensitive else { return }
        guard !shouldIgnoreClipboardSourceApp() else { return }

        if clipboardHistory.first?.text == clipboardText {
            return
        }

        let entry = ClipboardHistoryEntry(
            text: clipboardText,
            contentType: contentType
        )
        clipboardHistory.insert(entry, at: 0)
        clipboardHistory = Array(clipboardHistory.prefix(clipboardHistoryLimit))
        try? await clipboardHistoryStore.save(clipboardHistory, limit: clipboardHistoryLimit)
    }

    private func shouldIgnoreClipboardSourceApp() -> Bool {
        guard let bundleID = currentClipboardSourceAppBundleIdentifier, !bundleID.isEmpty else {
            return false
        }
        return settings.ignoredClipboardSourceBundleIDs.contains {
            $0.caseInsensitiveCompare(bundleID) == .orderedSame
        }
    }

    private func resolveClipboardSourceApp(bundleIdentifier: String, preferredName: String?) -> ClipboardSourceAppOption {
        if let knownApp = installedClipboardSourceApps.first(where: {
            $0.bundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }) {
            return knownApp
        }

        if let appURL = clipboardSourceAppURLResolver(bundleIdentifier),
           let discoveredApp = Self.makeClipboardSourceAppOption(from: appURL, preferredBundleIdentifier: bundleIdentifier) {
            return discoveredApp
        }

        return ClipboardSourceAppOption(
            bundleIdentifier: bundleIdentifier,
            name: preferredName ?? bundleIdentifier,
            path: ""
        )
    }

    nonisolated private static func discoverInstalledClipboardSourceApps() -> [ClipboardSourceAppOption] {
        let fileManager = FileManager.default
        let searchRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]

        var appsByBundleID: [String: ClipboardSourceAppOption] = [:]

        for root in searchRoots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame else { continue }
                defer { enumerator.skipDescendants() }

                guard let app = makeClipboardSourceAppOption(from: url, preferredBundleIdentifier: nil) else { continue }
                if appsByBundleID[app.bundleIdentifier] == nil {
                    appsByBundleID[app.bundleIdentifier] = app
                }
            }
        }

        return appsByBundleID.values.sorted {
            let order = $0.name.localizedCaseInsensitiveCompare($1.name)
            if order == .orderedSame {
                return $0.bundleIdentifier.localizedCaseInsensitiveCompare($1.bundleIdentifier) == .orderedAscending
            }
            return order == .orderedAscending
        }
    }

    nonisolated private static func makeClipboardSourceAppOption(from url: URL, preferredBundleIdentifier: String?) -> ClipboardSourceAppOption? {
        guard let bundle = Bundle(url: url) else { return nil }
        let bundleIdentifier = bundle.bundleIdentifier ?? preferredBundleIdentifier
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return nil }

        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        return ClipboardSourceAppOption(
            bundleIdentifier: bundleIdentifier,
            name: appName,
            path: url.path
        )
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
        history = Array(history.prefix(FileHistoryStore.defaultMaxEntries))
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

    // ── Welcome screen ───────────────────────────────────────────────────────

    func checkWelcomeScreenNeeded() {
        isWelcomeVisible = settings.lastSeenVersion.isEmpty
    }

    func dismissWelcome() async {
        isWelcomeVisible = false
        settings.lastSeenVersion = currentVersion
        await persistSettings()
    }

    func showWelcome() {
        isWelcomeVisible = true
    }

    /// Debug/testing: resets firstRun state so the welcome sheet appears again.
    func debugResetFirstRun() async {
        settings.lastSeenVersion = ""
        await persistSettings()
        isWelcomeVisible = true
    }

    func updateCheckForUpdatesOnLaunch(_ enabled: Bool) async {
        settings.checkForUpdatesOnLaunch = enabled
        await persistSettings()
    }

    /// "Show welcome on next start" toggle — clears or restores lastSeenVersion.
    func setShowWelcomeOnNextLaunch(_ enabled: Bool) async {
        settings.lastSeenVersion = enabled ? "" : currentVersion
        await persistSettings()
    }

    var showWelcomeOnNextLaunch: Bool {
        settings.lastSeenVersion.isEmpty
    }

    /// Silently checks for updates on launch — never sets error state, swallows all failures.
    func checkForUpdateSilentlyOnLaunch() async {
        guard settings.checkForUpdatesOnLaunch, updateState == .idle else { return }
        do {
            let url = URL(string: "https://api.github.com/repos/Arthur-Ficial/apfel-clip/releases/latest")!
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else { return }
            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            if Self.isVersionNewer(latestVersion, than: currentVersion) {
                updateState = .updateAvailable(newVersion: latestVersion)
            }
        } catch {
            // Silent: never surface network errors from background launch check
        }
    }

    // ── Update checking ──────────────────────────────────────────────────────

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    var isHomebrewInstall: Bool {
        FileManager.default.fileExists(atPath: "/opt/homebrew/Caskroom/apfel-clip")
    }

    static func isVersionNewer(_ candidate: String, than current: String) -> Bool {
        let cParts = candidate.split(separator: ".").compactMap { Int($0) }
        let kParts = current.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(cParts.count, kParts.count)
        let cPadded = cParts + Array(repeating: 0, count: maxLen - cParts.count)
        let kPadded = kParts + Array(repeating: 0, count: maxLen - kParts.count)
        for (c, k) in zip(cPadded, kPadded) {
            if c > k { return true }
            if c < k { return false }
        }
        return false
    }

    func checkForUpdate() async {
        updateState = .checking
        do {
            let url = URL(string: "https://api.github.com/repos/Arthur-Ficial/apfel-clip/releases/latest")!
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                updateState = .error(message: "Could not parse release info")
                return
            }
            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            if Self.isVersionNewer(latestVersion, than: currentVersion) {
                updateState = .updateAvailable(newVersion: latestVersion)
            } else {
                updateState = .upToDate
            }
        } catch {
            updateState = .error(message: error.localizedDescription)
        }
    }

    func installUpdate() {
        guard case .updateAvailable(let version) = updateState else { return }
        updateState = .installing(newVersion: version)
        let isHB = isHomebrewInstall
        Task.detached { [weak self, version, isHB] in
            if isHB {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", "brew upgrade apfel-clip"]
                do {
                    try process.run()
                    process.waitUntilExit()
                    await MainActor.run { self?.updateState = .installed(newVersion: version) }
                } catch {
                    await MainActor.run { self?.updateState = .error(message: error.localizedDescription) }
                }
            } else {
                await MainActor.run {
                    NSWorkspace.shared.open(URL(string: "https://github.com/Arthur-Ficial/apfel-clip/releases/latest")!)
                    self?.updateState = .idle
                }
            }
        }
    }

    func relaunch() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let bundlePath = Bundle.main.bundleURL.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "(while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; open '\(bundlePath)') &"]
        try? process.run()
        Thread.sleep(forTimeInterval: 0.15)
        exit(0)
    }

    private func persistSettings() async {
        await settingsStore.save(settings)
    }
}
