import Foundation

final class ClipControlAPI: @unchecked Sendable {
    let viewModel: PopoverViewModel
    weak var presenter: PopoverPresenting?

    init(viewModel: PopoverViewModel, presenter: PopoverPresenting?) {
        self.viewModel = viewModel
        self.presenter = presenter
    }

    func handle(method: String, path: String, query: String = "", body: String = "") async -> String {
        switch (method, path) {
        case ("GET", "/"), ("GET", ""):
            return help()
        case ("GET", "/health"):
            return await health()
        case ("GET", "/state"):
            return await state()
        case ("GET", "/clipboard"):
            return await clipboard()
        case ("POST", "/clipboard"):
            return await updateClipboard(body)
        case ("GET", "/actions"):
            return await actions()
        case ("POST", "/run"):
            return await run(body)
        case ("GET", "/history"):
            return await history()
        case ("POST", "/history/clear"):
            await viewModel.clearHistory()
            return ok()
        case ("GET", "/settings"):
            return await settings()
        case ("POST", "/settings"):
            return await updateSettings(body)
        case ("POST", "/ui/show"):
            await MainActor.run {
                presenter?.showPopover()
            }
            return ok()
        case ("POST", "/ui/hide"):
            await MainActor.run {
                presenter?.hidePopover()
            }
            return ok()
        case ("GET", "/welcome"):
            return await welcomeStatus()
        case ("POST", "/welcome/show"):
            await MainActor.run { viewModel.showWelcome() }
            return await welcomeStatus()
        case ("POST", "/welcome/dismiss"):
            await viewModel.dismissWelcome()
            return await welcomeStatus()
        case ("GET", "/update"):
            return await updateStatus()
        case ("POST", "/update/check"):
            await viewModel.checkForUpdate()
            return await updateStatus()
        case ("POST", "/update/install"):
            await MainActor.run { viewModel.installUpdate() }
            return await updateStatus()
        case ("POST", "/update/relaunch"):
            let response = await updateStatus()
            Task { @MainActor in viewModel.relaunch() }
            return response
        default:
            return err("Unknown route.")
        }
    }

    private func help() -> String {
        ok([
            "name": "apfel-clip control API",
            "endpoints": [
                "GET  /health",
                "GET  /state",
                "GET  /clipboard",
                "POST /clipboard",
                "GET  /actions",
                "POST /run",
                "GET  /history",
                "POST /history/clear",
                "GET  /settings",
                "POST /settings",
                "POST /ui/show",
                "POST /ui/hide",
                "GET  /welcome",
                "POST /welcome/show",
                "POST /welcome/dismiss",
                "GET  /update",
                "POST /update/check",
                "POST /update/install",
                "POST /update/relaunch",
            ],
        ])
    }

    private func health() async -> String {
        await MainActor.run { () -> String in
            var payload: [String: Any] = [
                "screen": viewModel.screen.rawValue,
                "server_state": serverStatePayload(viewModel.serverState),
            ]
            if let controlPort = viewModel.controlPort {
                payload["control_port"] = controlPort
            }
            return ok(payload)
        }
    }

    private func state() async -> String {
        await MainActor.run { () -> String in
            var payload: [String: Any] = [
                "screen": viewModel.screen.rawValue,
                "preferred_panel": viewModel.settings.preferredPanel.rawValue,
                "is_running": viewModel.isRunning,
                "launch_at_login": viewModel.settings.launchAtLoginEnabled,
                "clipboard_text": viewModel.clipboardText,
                "content_type": viewModel.contentType.rawValue,
                "history_count": viewModel.history.count,
                "available_actions": viewModel.availableActions.map(actionDictionary),
                "server_state": serverStatePayload(viewModel.serverState),
            ]

            if let banner = viewModel.banner {
                payload["banner"] = [
                    "style": banner.style.rawValue,
                    "title": banner.title,
                    "detail": banner.detail ?? "",
                ]
            }

            if let result = viewModel.result {
                payload["result"] = resultDictionary(result)
            }

            if let controlPort = viewModel.controlPort {
                payload["control_port"] = controlPort
            }

            return ok(payload)
        }
    }

    private func clipboard() async -> String {
        await MainActor.run { () -> String in
            ok([
                "text": viewModel.clipboardText,
                "content_type": viewModel.contentType.rawValue,
            ])
        }
    }

    private func updateClipboard(_ body: String) async -> String {
        guard let object = parseJSON(body), let text = object["text"] as? String else {
            return err("Need {\"text\": \"...\"}.")
        }

        await MainActor.run {
            viewModel.setClipboardText(text)
        }
        return await clipboard()
    }

    private func actions() async -> String {
        await MainActor.run { () -> String in
            ok([
                "content_type": viewModel.contentType.rawValue,
                "actions": viewModel.availableActions.map(actionDictionary),
                "all_actions": viewModel.allActions.map(managedActionDictionary),
            ])
        }
    }

    private func run(_ body: String) async -> String {
        guard let object = parseJSON(body) else {
            return err("Invalid JSON body.")
        }

        if let text = object["text"] as? String {
            await MainActor.run {
                viewModel.setClipboardText(text)
            }
        }

        do {
            if let actionID = object["action_id"] as? String {
                let result = try await viewModel.runAction(id: actionID)
                return ok(["result": resultDictionary(result)])
            }
            if let prompt = object["prompt"] as? String {
                let result = try await viewModel.runCustomPrompt(prompt)
                return ok(["result": resultDictionary(result)])
            }
            return err("Need {\"action_id\": \"...\"} or {\"prompt\": \"...\"}.")
        } catch {
            return err(error.localizedDescription)
        }
    }

    private func history() async -> String {
        await MainActor.run { () -> String in
            ok([
                "items": viewModel.history.map(historyDictionary),
            ])
        }
    }

    private func settings() async -> String {
        await MainActor.run { () -> String in
            ok([
                "auto_copy": viewModel.settings.autoCopy,
                "launch_at_login": viewModel.settings.launchAtLoginEnabled,
                "preferred_panel": viewModel.settings.preferredPanel.rawValue,
                "recent_custom_prompts": viewModel.settings.recentCustomPrompts,
                "favorite_action_ids": viewModel.settings.favoriteActionIDs,
                "hidden_action_ids": viewModel.settings.hiddenActionIDs,
            ])
        }
    }

    private func updateSettings(_ body: String) async -> String {
        guard let object = parseJSON(body) else {
            return err("Invalid JSON body.")
        }

        let autoCopy = object["auto_copy"] as? Bool
        let launchAtLogin = object["launch_at_login"] as? Bool
        let preferredPanel = (object["preferred_panel"] as? String).flatMap(ClipPrimaryPanel.init(rawValue:))
        let prompts = object["recent_custom_prompts"] as? [String]
        let favoriteActionIDs = object["favorite_action_ids"] as? [String]
        let hiddenActionIDs = object["hidden_action_ids"] as? [String]
        let checkForUpdatesOnLaunch = object["check_for_updates_on_launch"] as? Bool

        await viewModel.applySettings(
            autoCopy: autoCopy,
            preferredPanel: preferredPanel,
            recentCustomPrompts: prompts,
            favoriteActionIDs: favoriteActionIDs,
            hiddenActionIDs: hiddenActionIDs,
            checkForUpdatesOnLaunch: checkForUpdatesOnLaunch
        )
        if let launchAtLogin {
            await viewModel.updateLaunchAtLogin(launchAtLogin)
        }
        return await settings()
    }

    private func welcomeStatus() async -> String {
        await MainActor.run { () -> String in
            ok([
                "visible": viewModel.isWelcomeVisible,
                "current_version": viewModel.currentVersion,
                "check_for_updates_on_launch": viewModel.settings.checkForUpdatesOnLaunch,
                "last_seen_version": viewModel.settings.lastSeenVersion,
            ])
        }
    }

    private func updateStatus() async -> String {
        await MainActor.run { () -> String in
            let state = viewModel.updateState
            var payload: [String: Any] = [
                "current_version": viewModel.currentVersion,
                "install_method": viewModel.isHomebrewInstall ? "homebrew" : "direct",
                "update_available": false,
            ]
            switch state {
            case .idle:
                payload["state"] = "idle"
            case .checking:
                payload["state"] = "checking"
            case .upToDate:
                payload["state"] = "up_to_date"
            case .updateAvailable(let version):
                payload["state"] = "update_available"
                payload["latest_version"] = version
                payload["update_available"] = true
            case .installing(let version):
                payload["state"] = "installing"
                payload["latest_version"] = version
            case .installed(let version):
                payload["state"] = "installed"
                payload["latest_version"] = version
            case .error(let message):
                payload["state"] = "error"
                payload["message"] = message
            }
            return ok(payload)
        }
    }

    private func serverStatePayload(_ state: ClipServerState) -> [String: Any] {
        switch state {
        case .starting:
            return ["status": "starting"]
        case .ready(let port):
            return ["status": "ready", "port": port]
        case .failed(let message):
            return ["status": "failed", "message": message]
        }
    }

    private func actionDictionary(_ action: ClipAction) -> [String: Any] {
        [
            "id": action.id,
            "name": action.name,
            "icon": action.icon,
            "is_local": action.localAction != nil,
        ]
    }

    @MainActor
    private func managedActionDictionary(_ action: ClipAction) -> [String: Any] {
        [
            "id": action.id,
            "name": action.name,
            "icon": action.icon,
            "content_types": action.contentTypes.map(\.rawValue).sorted(),
            "is_local": action.localAction != nil,
            "is_available": viewModel.availableActions.contains(where: { $0.id == action.id }),
            "is_favorite": viewModel.isFavorite(action.id),
            "is_hidden": viewModel.isHidden(action.id),
        ]
    }

    private func historyDictionary(_ entry: ClipHistoryEntry) -> [String: Any] {
        [
            "id": entry.id,
            "action_id": entry.actionID,
            "action_name": entry.actionName,
            "input": entry.input,
            "output": entry.output,
            "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
        ]
    }

    private func resultDictionary(_ result: ClipResultState) -> [String: Any] {
        [
            "action_id": result.actionID,
            "action_name": result.actionName,
            "input": result.input,
            "output": result.output,
            "copied_to_clipboard": result.copiedToClipboard,
            "from_history": result.createdFromHistory,
        ]
    }

    private func ok(_ extra: [String: Any] = [:]) -> String {
        var payload: [String: Any] = ["status": "ok"]
        for (key, value) in extra {
            payload[key] = value
        }
        return jsonString(payload)
    }

    private func err(_ message: String) -> String {
        jsonString(["status": "error", "error": message])
    }

    private func parseJSON(_ body: String) -> [String: Any]? {
        guard let data = body.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func jsonString(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return "{\"status\":\"error\",\"error\":\"serialization failed\"}"
        }
        return String(decoding: data, as: UTF8.self)
    }
}

final class ClipControlServer: @unchecked Sendable {
    private let api: ClipControlAPI
    private var listener: Int32 = -1
    private var isRunning = false

    init(api: ClipControlAPI) {
        self.api = api
    }

    @discardableResult
    func start() -> Int? {
        for port in 11436...11439 {
            if let descriptor = createControlListenerSocket(port: UInt16(port)) {
                listener = descriptor
                isRunning = true
                let api = self.api
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    self?.acceptLoop(listener: descriptor, api: api)
                }
                return port
            }
        }
        return nil
    }

    func stop() {
        isRunning = false
        if listener >= 0 {
            close(listener)
            listener = -1
        }
    }

    private func acceptLoop(listener: Int32, api: ClipControlAPI) {
        while isRunning {
            var clientAddress = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let client = withUnsafeMutablePointer(to: &clientAddress) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(listener, $0, &length)
                }
            }

            guard client >= 0 else {
                if !isRunning {
                    break
                }
                continue
            }

            Task {
                await Self.handleConnection(client: client, api: api)
            }
        }
    }

    private static func handleConnection(client: Int32, api: ClipControlAPI) async {
        var buffer = [UInt8](repeating: 0, count: 32_768)
        let readCount = read(client, &buffer, buffer.count)
        guard readCount > 0 else {
            close(client)
            return
        }

        let request = String(decoding: buffer.prefix(readCount), as: UTF8.self)
        let firstLine = request.split(separator: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            close(client)
            return
        }

        let method = String(parts[0])
        let fullPath = String(parts[1])
        let pathComponents = fullPath.split(separator: "?", maxSplits: 1)
        let path = String(pathComponents[0])
        let query = pathComponents.count > 1 ? String(pathComponents[1]) : ""
        let body: String
        if let separator = request.range(of: "\r\n\r\n") {
            body = String(request[separator.upperBound...])
        } else {
            body = ""
        }

        let response = await api.handle(method: method, path: path, query: query, body: body)
        let payload = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        Content-Length: \(response.utf8.count)\r
        \r
        \(response)
        """
        _ = payload.withCString { pointer in
            write(client, pointer, Int(strlen(pointer)))
        }
        close(client)
    }
}

private func createControlListenerSocket(port: UInt16) -> Int32? {
    let descriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard descriptor >= 0 else { return nil }

    var option: Int32 = 1
    setsockopt(
        descriptor,
        SOL_SOCKET,
        SO_REUSEADDR,
        &option,
        socklen_t(MemoryLayout<Int32>.size)
    )

    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    address.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.bind(
                descriptor,
                socketAddress,
                socklen_t(MemoryLayout<sockaddr_in>.size)
            )
        }
    }

    guard result == 0, listen(descriptor, 8) == 0 else {
        close(descriptor)
        return nil
    }

    return descriptor
}
