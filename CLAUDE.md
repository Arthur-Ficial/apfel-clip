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

## Handling GitHub Issues

When a new issue comes in, follow this process:

1. **Fetch** the full issue with `gh issue view <n> --repo Arthur-Ficial/apfel-clip --json body,comments,title,author,labels`
2. **Vet** - is it a real bug, valid feature request, or noise?
   - Does it align with the purpose (fast, private, local clipboard AI)?
   - Can you reproduce it or trace the root cause in code?
   - Check comments for additional context
3. **Fix** if valid:
   - Write tests first (TDD) for bugs
   - Keep changes minimal and focused
   - Run `swift test` - all tests must pass
4. **Release** if code changed - run `./scripts/release.sh`
5. **Close** the issue with a short, truthful comment:
   - What was the problem and root cause
   - What was fixed (or why closed without a fix)
   - How to update (`brew upgrade apfel-clip` or download from releases)
6. **Homebrew tap:** cask files live in `Casks/` in `Arthur-Ficial/homebrew-tap` (NOT `Formula/`). Formula files for CLI tools go in `Formula/`.
