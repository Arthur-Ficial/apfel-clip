import Testing
@testable import apfel_clip

@Suite("ClipActionCatalog")
struct ClipActionCatalogTests {
    @Test("JSON actions include local formatter")
    func jsonActions() {
        let actions = ClipActionCatalog.actions(for: .json)
        #expect(actions.contains(where: { $0.id == "pretty-json" && $0.localAction == .prettyJSON }))
        #expect(actions.contains(where: { $0.id == "explain-json" }))
    }

    @Test("Text actions include translators")
    func textActions() {
        let actions = ClipActionCatalog.actions(for: .text)
        #expect(actions.contains(where: { $0.id == "translate-de" }))
        #expect(actions.contains(where: { $0.id == "fix-grammar" }))
    }
}
