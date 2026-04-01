# apfel-clip - Project Instructions

## Purpose

macOS menu bar app - AI-powered clipboard actions via [apfel](https://github.com/Arthur-Ficial/apfel). Pure HTTP consumer of `apfel --serve`. No model logic, no FoundationModels dependency.

## Build & Run

```bash
swift build -c release
make install
apfel-clip
```

Requires `apfel` installed and in PATH. Uses port 11435.

## Architecture

```
main.swift -> AppDelegate
  |- NSStatusItem (menu bar icon)
  |- NSPopover -> PopoverView (SwiftUI)
  |    |- ActionListView (content-aware action buttons)
  |    |- ResultView (before/after + "Copied!" banner)
  |    |- HistoryView (last 10 transformations)
  |    '- Custom prompt input
  |- ClipboardMonitor (polls NSPasteboard every 500ms)
  |- ContentDetector (heuristic: code/error/command/JSON/text)
  |- ActionRunner -> APIClient (POST /v1/chat/completions)
  '- ServerManager (spawns apfel --serve --port 11435)
```

## Key Files

| File | Purpose |
|------|---------|
| `Sources/main.swift` | Entry point, NSApp setup |
| `Sources/AppDelegate.swift` | Menu bar, popover, server lifecycle, hotkey |
| `Sources/APIClient.swift` | HTTP client for apfel server |
| `Sources/ClipboardMonitor.swift` | Clipboard change detection |
| `Sources/ContentDetector.swift` | Content type heuristics |
| `Sources/Actions.swift` | Action definitions with system prompts |
| `Sources/ActionRunner.swift` | Executes actions against server |
| `Sources/PopoverView.swift` | Main popover layout and state machine |
| `Sources/ActionListView.swift` | Action buttons with hover effects |
| `Sources/ResultView.swift` | Before/after display with auto-copy |
| `Sources/HistoryView.swift` | Recent transformations |
| `Sources/TokenEstimator.swift` | Token count estimation |

## Notes

- Port 11435 (different from apfel default 11434 and apfel-gui 11434)
- No external Swift package dependencies
- LSUIElement=true in Info.plist (no dock icon)
- System prompts use strict prefix to prevent AI from adding commentary
