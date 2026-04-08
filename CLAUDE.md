# apfel-clip - Project Instructions

## Purpose

macOS menu bar app — AI-powered clipboard actions via [apfel](https://github.com/Arthur-Ficial/apfel). Pure HTTP consumer of `apfel --serve`. No model logic, no FoundationModels dependency.

## Build & Run

```bash
swift build -c release
make install
apfel-clip
```

Requires `apfel` in PATH. Uses port 11435.

## Architecture

MVVM, `@Observable` ViewModel, Swift actors for stores.

```
App/ApfelClipApp.swift  →  App/AppDelegate.swift
  ├─ Services/ServerManager        — spawns apfel --serve --port 11435
  ├─ Services/PasteboardClipboardService  — polls NSPasteboard every 500ms
  ├─ Services/ConfigurableClipActionExecutor  — routes to ApfelClipService or local
  ├─ Services/ApfelClipService     — POST /v1/chat/completions
  ├─ Services/FileHistoryStore     — ~/Library/Application Support/apfel-clip/history.json
  ├─ Services/UserDefaultsSettingsStore  — UserDefaults "apfel-clip.settings"
  ├─ Services/ClipControlServer    — local HTTP control API (automation)
  ├─ ViewModels/PopoverViewModel   — all app state + business logic (@Observable)
  └─ Views/PopoverRootView         — SwiftUI popover (540×820)
       ├─ actionsPanel             — content-type-aware action buttons, drag-to-reorder
       ├─ resultPanel              — original → action → editable result
       ├─ historyPanel             — recent transformations
       ├─ customPromptPanel        — free-text prompt + "Save as Action"
       ├─ settingsPanel            — auto-copy, saved actions CRUD, action manager
       └─ SavedActionForm.swift    — icon picker + create/edit form for saved actions
```

## Key Models

| Type | Purpose |
|------|---------|
| `ClipAction` | Built-in action (id, name, icon, systemPrompt, instruction, contentTypes) |
| `SavedCustomAction` | User-saved prompt as a named action |
| `ClipSettings` | Persisted preferences (autoCopy, favorites, hidden, saved actions, order) |
| `ClipHistoryEntry` | One transformation record |
| `ClipResultState` | In-memory result shown in result panel |
| `ContentType` | text / code / json / error — drives action filtering |

## Notes

- `ClipActionCatalog.strict` — shared "no commentary" suffix for all system prompts
- Port 11435 (different from apfel default 11434)
- LSUIElement=true in Info.plist (no dock icon)
- No external Swift package dependencies
- Popover created after settings load — never shown with empty defaults
