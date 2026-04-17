# Configurable Hotkey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users change the global keyboard shortcut that toggles the apfel-clip popover (currently hardcoded to Cmd+Shift+V).

**Architecture:** Add a `HotkeyConfig` struct to `ClipSettings` (persisted via UserDefaults). `AppDelegate` reads the config on launch and re-registers the global monitor when it changes. A `HotkeyRecorderView` in the settings panel captures new key combos via `NSEvent.addLocalMonitorForEvents`. The header's shortcut label becomes dynamic.

**Tech Stack:** Swift 6, SwiftUI, AppKit (NSEvent global/local monitors), swift-testing

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `Sources/Models/ClipSettings.swift` | Modify | Add `HotkeyConfig` struct + field to `ClipSettings` |
| `Sources/ViewModels/PopoverViewModel.swift` | Modify | Add `updateHotkey(_:)`, expose `hotkeyDisplayLabel` |
| `Sources/App/AppDelegate.swift` | Modify | Read hotkey from settings, support re-registration via `reconfigureHotkey()` |
| `Sources/Views/HotkeyRecorderView.swift` | Create | SwiftUI view that captures a key combo via local NSEvent monitor |
| `Sources/Views/PopoverRootView.swift` | Modify | Add hotkey setting row in settings panel, make header label dynamic |
| `Tests/HotkeyConfigTests.swift` | Create | Unit tests for `HotkeyConfig` model (Codable, display label, equality) |
| `Tests/HotkeySettingsTests.swift` | Create | Unit tests for ViewModel hotkey update + persistence round-trip |

---

### Task 1: HotkeyConfig model

**Files:**
- Modify: `Sources/Models/ClipSettings.swift`
- Create: `Tests/HotkeyConfigTests.swift`

- [ ] **Step 1: Write failing tests for HotkeyConfig**

Create `Tests/HotkeyConfigTests.swift`:

```swift
import Foundation
import Testing
@testable import apfel_clip

@Suite("HotkeyConfig")
struct HotkeyConfigTests {

    @Test("Default hotkey is Cmd+Shift+V")
    func defaultHotkey() {
        let config = HotkeyConfig()
        #expect(config.key == "v")
        #expect(config.modifiers == [.command, .shift])
    }

    @Test("Display label for default hotkey")
    func defaultDisplayLabel() {
        let config = HotkeyConfig()
        #expect(config.displayLabel == "\u{2318}\u{21E7}V")
    }

    @Test("Display label for Cmd+Opt+A")
    func customDisplayLabel() {
        let config = HotkeyConfig(key: "a", modifiers: [.command, .option])
        #expect(config.displayLabel == "\u{2325}\u{2318}A")
    }

    @Test("Display label for Ctrl+Shift+K")
    func ctrlShiftDisplayLabel() {
        let config = HotkeyConfig(key: "k", modifiers: [.control, .shift])
        #expect(config.displayLabel == "\u{2303}\u{21E7}K")
    }

    @Test("Codable round-trip preserves values")
    func codableRoundTrip() throws {
        let original = HotkeyConfig(key: "j", modifiers: [.command, .option, .shift])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyConfig.self, from: data)
        #expect(decoded == original)
    }

    @Test("ClipSettings default includes default hotkey")
    func settingsDefaultHotkey() {
        let settings = ClipSettings()
        #expect(settings.hotkey == HotkeyConfig())
    }

    @Test("ClipSettings with custom hotkey round-trips through JSON")
    func settingsHotkeyRoundTrip() throws {
        var settings = ClipSettings()
        settings.hotkey = HotkeyConfig(key: "b", modifiers: [.command, .control])
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ClipSettings.self, from: data)
        #expect(decoded.hotkey.key == "b")
        #expect(decoded.hotkey.modifiers == [.command, .control])
    }

    @Test("Decoding ClipSettings without hotkey field uses default")
    func backwardsCompatibility() throws {
        // Simulate settings saved by an older version (no hotkey field)
        let json = """
        {"autoCopy":true,"launchAtLoginEnabled":false,"launchAtLoginPromptShown":true,
         "recentCustomPrompts":[],"preferredPanel":"actions","favoriteActionIDs":[],
         "hiddenActionIDs":[],"savedCustomActions":[],"actionOrder":[],
         "checkForUpdatesOnLaunch":true,"lastSeenVersion":"0.4.1"}
        """
        let data = json.data(using: .utf8)!
        let settings = try JSONDecoder().decode(ClipSettings.self, from: data)
        #expect(settings.hotkey == HotkeyConfig())
        #expect(settings.autoCopy == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/dev/apfel-clip && swift test --filter HotkeyConfigTests 2>&1 | tail -5`
Expected: compilation error - `HotkeyConfig` not defined.

- [ ] **Step 3: Implement HotkeyConfig and add to ClipSettings**

In `Sources/Models/ClipSettings.swift`, add before the `ClipSettings` struct:

```swift
struct HotkeyModifier: OptionSet, Codable, Equatable, Hashable, Sendable {
    let rawValue: UInt

    static let command = HotkeyModifier(rawValue: 1 << 0)
    static let shift   = HotkeyModifier(rawValue: 1 << 1)
    static let option  = HotkeyModifier(rawValue: 1 << 2)
    static let control = HotkeyModifier(rawValue: 1 << 3)
}

struct HotkeyConfig: Codable, Equatable, Hashable, Sendable {
    var key: String
    var modifiers: HotkeyModifier

    init(key: String = "v", modifiers: HotkeyModifier = [.command, .shift]) {
        self.key = key
        self.modifiers = modifiers
    }

    var displayLabel: String {
        var parts: [String] = []
        // macOS standard order: Ctrl, Opt, Shift, Cmd
        if modifiers.contains(.control) { parts.append("\u{2303}") }
        if modifiers.contains(.option)  { parts.append("\u{2325}") }
        if modifiers.contains(.shift)   { parts.append("\u{21E7}") }
        if modifiers.contains(.command) { parts.append("\u{2318}") }
        parts.append(key.uppercased())
        return parts.joined()
    }

    /// Convert to NSEvent.ModifierFlags for use with NSEvent monitors.
    var nsModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.shift)   { flags.insert(.shift) }
        if modifiers.contains(.option)  { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        return flags
    }

    /// Create from an NSEvent's modifier flags and characters.
    static func from(event: NSEvent) -> HotkeyConfig? {
        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              !chars.isEmpty else { return nil }
        var mods: HotkeyModifier = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.shift)   { mods.insert(.shift) }
        if flags.contains(.option)  { mods.insert(.option) }
        if flags.contains(.control) { mods.insert(.control) }
        guard !mods.isEmpty else { return nil }
        return HotkeyConfig(key: chars, modifiers: mods)
    }
}
```

Add `import AppKit` at the top of `ClipSettings.swift` (needed for `NSEvent`).

Add the `hotkey` field to `ClipSettings`:

```swift
var hotkey: HotkeyConfig = HotkeyConfig()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/dev/apfel-clip && swift test --filter HotkeyConfigTests 2>&1 | tail -10`
Expected: all 8 tests pass.

- [ ] **Step 5: Run full test suite to check for regressions**

Run: `cd ~/dev/apfel-clip && swift test 2>&1 | tail -10`
Expected: all existing tests pass (the new `hotkey` field has a default so old `ClipSettings()` calls are unchanged).

- [ ] **Step 6: Commit**

```bash
cd ~/dev/apfel-clip
git add Sources/Models/ClipSettings.swift Tests/HotkeyConfigTests.swift
git commit -m "feat: add HotkeyConfig model to ClipSettings (closes #6 step 1)"
```

---

### Task 2: ViewModel hotkey support

**Files:**
- Modify: `Sources/ViewModels/PopoverViewModel.swift`
- Create: `Tests/HotkeySettingsTests.swift`

- [ ] **Step 1: Write failing tests for ViewModel hotkey methods**

Create `Tests/HotkeySettingsTests.swift`:

```swift
import Foundation
import Testing
@testable import apfel_clip

@Suite("Hotkey Settings")
@MainActor
struct HotkeySettingsTests {
    private func makeViewModel() -> (PopoverViewModel, MockSettingsStore) {
        let executor = MockActionExecutor()
        let clipboard = MockClipboardService()
        let historyStore = MockHistoryStore()
        let settingsStore = MockSettingsStore()
        let launchAtLoginController = MockLaunchAtLoginController()
        let viewModel = PopoverViewModel(
            actionExecutor: executor,
            clipboardService: clipboard,
            historyStore: historyStore,
            settingsStore: settingsStore,
            launchAtLoginController: launchAtLoginController
        )
        return (viewModel, settingsStore)
    }

    @Test("Default hotkey display label is Cmd+Shift+V")
    func defaultHotkeyLabel() {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.hotkeyDisplayLabel == "\u{2318}\u{21E7}V")
    }

    @Test("updateHotkey persists the new hotkey config")
    func updateHotkeyPersists() async {
        let (viewModel, settingsStore) = makeViewModel()
        let newHotkey = HotkeyConfig(key: "a", modifiers: [.command, .option])

        await viewModel.updateHotkey(newHotkey)

        let saved = await settingsStore.load()
        #expect(saved.hotkey == newHotkey)
        #expect(viewModel.settings.hotkey == newHotkey)
    }

    @Test("hotkeyDisplayLabel reflects updated hotkey")
    func labelUpdatesAfterChange() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.updateHotkey(HotkeyConfig(key: "k", modifiers: [.control, .shift]))
        #expect(viewModel.hotkeyDisplayLabel == "\u{2303}\u{21E7}K")
    }

    @Test("Loaded settings preserve custom hotkey")
    func loadedSettingsPreserveHotkey() async {
        let (viewModel, settingsStore) = makeViewModel()
        var settings = ClipSettings()
        settings.hotkey = HotkeyConfig(key: "j", modifiers: [.command])
        await settingsStore.save(settings)

        await viewModel.loadPersistedState()

        #expect(viewModel.settings.hotkey.key == "j")
        #expect(viewModel.hotkeyDisplayLabel == "\u{2318}J")
    }

    @Test("onHotkeyChanged callback fires when hotkey is updated")
    func onHotkeyChangedCallbackFires() async {
        let (viewModel, _) = makeViewModel()
        var callbackHotkey: HotkeyConfig?
        viewModel.onHotkeyChanged = { config in callbackHotkey = config }

        let newHotkey = HotkeyConfig(key: "b", modifiers: [.command, .shift])
        await viewModel.updateHotkey(newHotkey)

        #expect(callbackHotkey == newHotkey)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/dev/apfel-clip && swift test --filter HotkeySettingsTests 2>&1 | tail -5`
Expected: compilation error - `hotkeyDisplayLabel` and `updateHotkey` not defined.

- [ ] **Step 3: Add hotkey methods to PopoverViewModel**

In `Sources/ViewModels/PopoverViewModel.swift`, add the callback property after the existing property declarations (around line 33):

```swift
var onHotkeyChanged: ((HotkeyConfig) -> Void)?
```

Add these methods (after the `updateAutoCopy` method, around line 407):

```swift
var hotkeyDisplayLabel: String {
    settings.hotkey.displayLabel
}

func updateHotkey(_ config: HotkeyConfig) async {
    settings.hotkey = config
    await persistSettings()
    onHotkeyChanged?(config)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/dev/apfel-clip && swift test --filter HotkeySettingsTests 2>&1 | tail -10`
Expected: all 5 tests pass.

- [ ] **Step 5: Run full test suite**

Run: `cd ~/dev/apfel-clip && swift test 2>&1 | tail -10`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd ~/dev/apfel-clip
git add Sources/ViewModels/PopoverViewModel.swift Tests/HotkeySettingsTests.swift
git commit -m "feat: add hotkey update + callback to PopoverViewModel"
```

---

### Task 3: AppDelegate hotkey re-registration

**Files:**
- Modify: `Sources/App/AppDelegate.swift`

- [ ] **Step 1: Refactor configureHotkey to accept a HotkeyConfig**

Replace the existing `configureHotkey()` method in `AppDelegate.swift` (lines 168-176) with:

```swift
private func configureHotkey() {
    let config = viewModel?.settings.hotkey ?? HotkeyConfig()
    registerHotkey(config)
}

func reconfigureHotkey(_ config: HotkeyConfig) {
    if let monitor = globalMonitor {
        NSEvent.removeMonitor(monitor)
        globalMonitor = nil
    }
    registerHotkey(config)
}

private func registerHotkey(_ config: HotkeyConfig) {
    let expectedFlags = config.nsModifierFlags
    let expectedKey = config.key.lowercased()
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
        let pressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard pressed.contains(expectedFlags),
              event.charactersIgnoringModifiers?.lowercased() == expectedKey else { return }
        Task { @MainActor in
            self?.togglePopover(nil)
        }
    }
}
```

- [ ] **Step 2: Wire up the onHotkeyChanged callback in bootstrap**

In `AppDelegate.bootstrap(viewModel:)`, after `configureHotkey()` is called (but still in the synchronous setup section before the `Task {}`), move `configureHotkey()` into the `bootstrap` method after `await viewModel.loadPersistedState()` so it reads persisted settings. Then wire the callback.

Replace the current `applicationDidFinishLaunching` and `bootstrap` to reorder hotkey setup:

In `applicationDidFinishLaunching`, remove the `configureHotkey()` call (line 34). It moves into `bootstrap`.

In `bootstrap(viewModel:)`, after `await viewModel.loadPersistedState()` (line 103), add:

```swift
configureHotkey()
viewModel.onHotkeyChanged = { [weak self] config in
    self?.reconfigureHotkey(config)
}
```

- [ ] **Step 3: Build and verify**

Run: `cd ~/dev/apfel-clip && swift build 2>&1 | tail -5`
Expected: build succeeds with no errors.

- [ ] **Step 4: Run full test suite**

Run: `cd ~/dev/apfel-clip && swift test 2>&1 | tail -10`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/dev/apfel-clip
git add Sources/App/AppDelegate.swift
git commit -m "feat: AppDelegate reads hotkey from settings and re-registers on change"
```

---

### Task 4: HotkeyRecorderView

**Files:**
- Create: `Sources/Views/HotkeyRecorderView.swift`

- [ ] **Step 1: Create the hotkey recorder view**

Create `Sources/Views/HotkeyRecorderView.swift`:

```swift
import SwiftUI

struct HotkeyRecorderView: View {
    @Binding var config: HotkeyConfig
    @State private var isRecording = false
    @State private var localMonitor: Any?

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            HStack(spacing: 6) {
                if isRecording {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.red)
                    Text("Press shortcut...")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                } else {
                    Text(config.displayLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.16, green: 0.49, blue: 0.22))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isRecording ? Color.red.opacity(0.08) : Color.white.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isRecording ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                stopRecording()
                return nil
            }
            if let newConfig = HotkeyConfig.from(event: event) {
                config = newConfig
                stopRecording()
            }
            return nil // swallow the event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd ~/dev/apfel-clip && swift build 2>&1 | tail -5`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
cd ~/dev/apfel-clip
git add Sources/Views/HotkeyRecorderView.swift
git commit -m "feat: add HotkeyRecorderView for capturing key combos"
```

---

### Task 5: Wire into settings panel and header

**Files:**
- Modify: `Sources/Views/PopoverRootView.swift`

- [ ] **Step 1: Add hotkey setting row to the settings panel**

In `Sources/Views/PopoverRootView.swift`, in the `settingsPanel` computed property, add a new `SurfaceCard` after the auto-copy toggle card (after line 528):

```swift
SurfaceCard {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Global shortcut")
                    .font(.subheadline.weight(.semibold))
                Text("Press to set a new keyboard shortcut for toggling apfel-clip.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HotkeyRecorderView(config: Binding(
                get: { viewModel.settings.hotkey },
                set: { newConfig in
                    Task { await viewModel.updateHotkey(newConfig) }
                }
            ))
        }
    }
}
```

- [ ] **Step 2: Make the header shortcut label dynamic**

In `PopoverRootView.swift`, in the `header` computed property, replace the hardcoded label (line 89):

```swift
Label("\u{2318}\u{21E7}V", systemImage: "keyboard")
```

with:

```swift
Label(viewModel.hotkeyDisplayLabel, systemImage: "keyboard")
```

- [ ] **Step 3: Build and verify**

Run: `cd ~/dev/apfel-clip && swift build 2>&1 | tail -5`
Expected: build succeeds.

- [ ] **Step 4: Run full test suite**

Run: `cd ~/dev/apfel-clip && swift test 2>&1 | tail -10`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/dev/apfel-clip
git add Sources/Views/PopoverRootView.swift
git commit -m "feat: add hotkey recorder to settings panel, dynamic shortcut label in header"
```

---

### Task 6: Update welcome text

**Files:**
- Modify: `Sources/ViewModels/PopoverViewModel.swift`

- [ ] **Step 1: Make seedWelcomeClipboardIfNeeded use dynamic label**

In `PopoverViewModel.swift`, update `seedWelcomeClipboardIfNeeded()` (around line 168). Replace the hardcoded `\u{2318}\u{21E7}V` with the dynamic label:

```swift
func seedWelcomeClipboardIfNeeded() {
    guard history.isEmpty && clipboardText.isEmpty else { return }
    setClipboardText("apfel-clip example - Copy any text, code, or error message. Press \(settings.hotkey.displayLabel) and pick an action: Fix Grammar, Summarise, Explain Code, and more. On-device AI, no API keys needed.")
}
```

- [ ] **Step 2: Build and verify**

Run: `cd ~/dev/apfel-clip && swift build 2>&1 | tail -5`
Expected: build succeeds.

- [ ] **Step 3: Run full test suite**

Run: `cd ~/dev/apfel-clip && swift test 2>&1 | tail -10`
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
cd ~/dev/apfel-clip
git add Sources/ViewModels/PopoverViewModel.swift
git commit -m "fix: use dynamic hotkey label in welcome seed text"
```

---

### Task 7: Final integration verification

- [ ] **Step 1: Run full test suite**

Run: `cd ~/dev/apfel-clip && swift test 2>&1 | tail -15`
Expected: all tests pass, 0 failures.

- [ ] **Step 2: Build release binary**

Run: `cd ~/dev/apfel-clip && swift build -c release 2>&1 | tail -5`
Expected: clean build, no warnings.

- [ ] **Step 3: Manual smoke test**

Run:
```bash
cd ~/dev/apfel-clip && make install && apfel-clip &
```

Verify:
1. App launches in menu bar
2. Cmd+Shift+V toggles popover (default hotkey)
3. Settings panel shows "Global shortcut" card with current shortcut displayed
4. Click the shortcut button, press a new combo (e.g. Cmd+Opt+V), verify it updates
5. Close and reopen popover - header shows new shortcut label
6. New shortcut toggles the popover
7. Cmd+Shift+V no longer toggles (old shortcut unregistered)

- [ ] **Step 4: Squash into a single feature commit (optional)**

If desired, squash the task commits into one:

```bash
cd ~/dev/apfel-clip
git rebase -i HEAD~6
# squash all into first, use message:
# feat: configurable global shortcut (closes #6)
```
