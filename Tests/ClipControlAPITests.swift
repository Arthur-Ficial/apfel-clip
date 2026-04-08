import Foundation
import Testing
@testable import apfel_clip

@Suite("ClipControlAPI")
@MainActor
struct ClipControlAPITests {
    private func makeAPI() async -> (ClipControlAPI, PopoverViewModel, MockPopoverPresenter, MockClipboardService) {
        let executor = MockActionExecutor()
        await executor.setNextResult("API result")
        let clipboard = MockClipboardService()
        clipboard.currentText = "original"
        let historyStore = MockHistoryStore()
        let settingsStore = MockSettingsStore()
        let viewModel = PopoverViewModel(
            actionExecutor: executor,
            clipboardService: clipboard,
            historyStore: historyStore,
            settingsStore: settingsStore
        )
        await viewModel.loadPersistedState()
        viewModel.refreshFromClipboard()
        let presenter = MockPopoverPresenter()
        let api = ClipControlAPI(viewModel: viewModel, presenter: presenter)
        return (api, viewModel, presenter, clipboard)
    }

    @Test("GET /actions reflects current clipboard type")
    func actionsRoute() async throws {
        let (api, _, _, _) = await makeAPI()
        let response = await api.handle(method: "GET", path: "/actions")
        let json = try parse(response)

        #expect(json["status"] as? String == "ok")
        let actions = json["actions"] as? [[String: Any]]
        let allActions = json["all_actions"] as? [[String: Any]]
        #expect((actions?.isEmpty ?? true) == false)
        #expect((allActions?.isEmpty ?? true) == false)
        #expect(allActions?.first?["is_favorite"] != nil)
        #expect(allActions?.first?["is_hidden"] != nil)
    }

    @Test("POST /run executes action and returns result")
    func runRoute() async throws {
        let (api, viewModel, _, _) = await makeAPI()
        let response = await api.handle(
            method: "POST",
            path: "/run",
            body: #"{"action_id":"fix-grammar","text":"teh text"}"#
        )
        let json = try parse(response)
        let result = json["result"] as? [String: Any]

        #expect(json["status"] as? String == "ok")
        #expect(result?["output"] as? String == "API result")
        #expect(viewModel.history.count == 1)
    }

    @Test("POST /settings updates settings")
    func settingsRoute() async throws {
        let (api, viewModel, _, _) = await makeAPI()
        let response = await api.handle(
            method: "POST",
            path: "/settings",
            body: #"{"auto_copy":false,"preferred_panel":"history","favorite_action_ids":["fix-grammar"],"hidden_action_ids":["translate-ja"]}"#
        )
        let json = try parse(response)

        #expect(viewModel.settings.autoCopy == false)
        #expect(viewModel.settings.preferredPanel == .history)
        #expect(viewModel.settings.favoriteActionIDs == ["fix-grammar"])
        #expect(viewModel.settings.hiddenActionIDs == ["translate-ja"])
        #expect(json["favorite_action_ids"] as? [String] == ["fix-grammar"])
        #expect(json["hidden_action_ids"] as? [String] == ["translate-ja"])
    }

    @Test("UI show route calls presenter")
    func uiShowRoute() async throws {
        let (api, _, presenter, _) = await makeAPI()
        _ = await api.handle(method: "POST", path: "/ui/show")
        #expect(presenter.showCount == 1)
    }

    @Test("Invalid body returns structured error")
    func invalidBody() async throws {
        let (api, _, _, _) = await makeAPI()
        let response = await api.handle(method: "POST", path: "/run", body: "{")
        let json = try parse(response)
        #expect(json["status"] as? String == "error")
    }

    private func parse(_ response: String) throws -> [String: Any] {
        let data = try #require(response.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
