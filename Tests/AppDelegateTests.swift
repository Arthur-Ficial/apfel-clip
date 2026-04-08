import AppKit
import Testing
@testable import apfel_clip

@Suite("AppDelegate")
@MainActor
struct AppDelegateTests {

    @Test("Context menu has Open, Launch at Login, Auto-Copy, and Quit items")
    func contextMenuHasExpectedItems() {
        let delegate = AppDelegate()
        let menu = delegate.buildContextMenu()
        let titles = menu.items.map { $0.title }
        #expect(titles.contains("Open apfel-clip"))
        #expect(titles.contains(where: { $0.contains("Launch at Login") }))
        #expect(titles.contains(where: { $0.contains("Auto-Copy") }))
        #expect(titles.contains("Quit apfel-clip"))
    }

    @Test("Context menu last item is Quit with terminate action")
    func contextMenuLastItemIsQuit() {
        let delegate = AppDelegate()
        let menu = delegate.buildContextMenu()
        let last = menu.items.last
        #expect(last?.title == "Quit apfel-clip")
        #expect(last?.action == #selector(NSApplication.terminate(_:)))
    }

    @Test("Context menu first item is Open with showPopover action")
    func contextMenuFirstItemIsOpen() {
        let delegate = AppDelegate()
        let menu = delegate.buildContextMenu()
        let first = menu.items.first
        #expect(first?.title == "Open apfel-clip")
        #expect(first?.action == #selector(AppDelegate.showPopover))
    }
}
