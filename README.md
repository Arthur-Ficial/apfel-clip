# apfel-clip

**AI clipboard actions for macOS. Local-first. Fast. Menu-bar native.**

Copy text, code, JSON, logs, or an error. Press `⌘⇧V`. Pick an action. Get back the next useful version of what you copied.

`apfel-clip` lives in your menu bar and uses [`apfel`](https://github.com/Arthur-Ficial/apfel) to run Apple's on-device model locally on your Mac. No API keys. No browser tab. No cloud round-trip.

**Website:** [apfel-clip.franzai.com](https://apfel-clip.franzai.com)  
**Releases:** [Latest release](https://github.com/Arthur-Ficial/apfel-clip/releases/latest)  
**Issues:** [Report a bug or request a feature](https://github.com/Arthur-Ficial/apfel-clip/issues)

[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B%20Tahoe-blue.svg)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2B-black.svg)](https://www.apple.com/mac/)

## Why apfel-clip

Most clipboard tools stop at copy and paste. Most AI tools pull you out of flow.

apfel-clip does the opposite:

- It stays in the menu bar.
- It opens instantly with `⌘⇧V`.
- It detects what is in the clipboard and shows the right actions.
- It keeps the result close to the original so you can review, edit, copy, and move on.

The goal is simple: make the clipboard feel like an action surface, not just temporary storage.

## Screenshots

<table>
<tr>
<td align="center" width="50%">
<img src="docs/screen-actions.png" width="320" alt="Text action suggestions"><br>
<strong>Text actions</strong> — fix grammar, rewrite tone, summarise
</td>
<td align="center" width="50%">
<img src="docs/screen-code.png" width="320" alt="Code action suggestions"><br>
<strong>Code actions</strong> — explain, find bugs, add comments
</td>
</tr>
<tr>
<td align="center" width="50%">
<img src="docs/screen-result.png" width="320" alt="Result panel"><br>
<strong>Workflow result view</strong> — original, action, result
</td>
<td align="center" width="50%">
<img src="docs/screen-history.png" width="320" alt="History panel"><br>
<strong>History</strong> — reopen or re-copy successful transformations
</td>
</tr>
</table>

## Highlights

- **Fully local**: no API keys, no cloud calls, no external prompt window.
- **Content-aware actions**: prose, code, shell commands, errors, and JSON get different action sets.
- **Global hotkey**: `⌘⇧V` opens the popover from anywhere.
- **Action manager**: favorite, hide, and drag-reorder actions.
- **Saved custom actions**: turn any prompt into a reusable action with its own name and icon.
- **Persistent history**: every successful transformation is stored locally.
- **Auto-copy**: optionally copy results back to the clipboard as soon as they finish.
- **Launch at login**: the app asks on first launch and lets you change it later in Settings.
- **Automation API**: a small local HTTP API for scripts and tooling.

## What it can do

apfel-clip detects what is in the clipboard and offers the matching tools:

| Content type | Built-in actions |
|---|---|
| **Text / prose** | Fix grammar, make concise, make formal, make casual, summarize, bullet points, translate to German/French/Spanish/Japanese |
| **Code** | Explain code, find bugs, add comments, simplify, summarize |
| **Error messages** | Explain error, suggest fix |
| **Shell commands** | Explain command, make safer |
| **JSON** | Explain structure, pretty format |
| **Anything** | Run a custom prompt and optionally save it as a reusable action |

## Requirements

apfel-clip currently targets the local Apple Intelligence stack, so you need:

| Requirement | Notes |
|---|---|
| **macOS 26 (Tahoe) or later** | The package target is `macOS(.v26)` |
| **Apple Silicon** | M1 or newer |
| **Apple Intelligence enabled** | Enable it in System Settings |

Packaged installs embed `apfel` inside the app bundle automatically.

If you build from source, install `apfel` first:

```bash
brew install Arthur-Ficial/tap/apfel
```

## Install

### 1. Homebrew tap

This is the best default path for most users.

```bash
brew tap Arthur-Ficial/tap
brew install --cask apfel-clip

# Update later
brew upgrade --cask apfel-clip
```

If you do not have Homebrew yet, install it from [brew.sh](https://brew.sh).

### 2. Direct download

1. Download [`apfel-clip-macos-arm64.zip`](https://github.com/Arthur-Ficial/apfel-clip/releases/latest/download/apfel-clip-macos-arm64.zip)
2. Unzip it
3. Move `apfel-clip.app` into `/Applications`

Optional checksum verification:

```bash
shasum -a 256 apfel-clip-macos-arm64.zip
```

Checksums are published alongside each release in `SHA256SUMS`.

### 3. One-line installer

```zsh
curl -fsSL https://raw.githubusercontent.com/Arthur-Ficial/apfel-clip/main/scripts/install.sh | zsh
```

This downloads the latest release, installs `apfel-clip.app` into `/Applications`, and links the CLI entrypoint into `~/.local/bin`.

### 4. Build from source

```bash
git clone https://github.com/Arthur-Ficial/apfel-clip.git
cd apfel-clip
make install
```

If you also want the CLI symlink:

```bash
make install-cli
```

## First launch

1. Open `apfel-clip.app` from `/Applications`
2. The clipboard icon appears in the menu bar
3. On first launch, the app asks whether it should start at login
4. Copy something and press `⌘⇧V`
5. Pick an action and review the result

The launch-at-login choice can be changed later in Settings.

### Gatekeeper

Official release archives are intended for normal macOS installation.  
Local source builds are ad hoc builds and may trigger Gatekeeper on first open.

If you open a source build and macOS blocks it:

1. Right-click `apfel-clip.app`
2. Choose **Open**
3. Confirm **Open** again

You only need to do that once for a local build.

## Daily workflow

The intended loop is short:

1. Copy text, code, JSON, or an error
2. Press `⌘⇧V`
3. Choose a suggested action or run a custom one
4. Review the result
5. Copy, edit, or reopen it later from History

The result view is intentionally explicit: original at the top, the action in the middle, result below. It is meant to read like a workflow, not a dump of text.

## Custom actions and action management

apfel-clip is not limited to the built-in catalog.

- Use **Custom** to run any prompt against the current clipboard content.
- Save successful prompts as named reusable actions.
- Scope saved actions to specific content types.
- Favorite the actions you use most.
- Hide actions you never want to see.
- Drag to reorder the list so your action panel matches how you work.

All of that state is stored locally.

## Automation API

apfel-clip exposes a local HTTP control API for scripting and automation.

- It binds to the first free local port in `11436...11439`
- It shares the same action execution path as the UI
- It can read clipboard state, run actions, inspect history, update settings, and show or hide the UI

Example:

```bash
curl http://127.0.0.1:11436/health

curl -X POST http://127.0.0.1:11436/run \
  -H "Content-Type: application/json" \
  -d '{"action_id":"fix-grammar"}'
```

Main routes:

- `GET /health`
- `GET /state`
- `GET /clipboard`
- `POST /clipboard`
- `GET /actions`
- `POST /run`
- `GET /history`
- `POST /history/clear`
- `GET /settings`
- `POST /settings`
- `POST /ui/show`
- `POST /ui/hide`

## Architecture

The codebase is organized like a small macOS product, not a single-file toy app:

```text
Sources/
├─ App/
│  ├─ ApfelClipApp.swift
│  └─ AppDelegate.swift
├─ Models/
├─ Protocols/
├─ Services/
├─ ViewModels/
└─ Views/
```

Core responsibilities:

- `AppDelegate`: status item, global hotkey, popover lifecycle, first-run launch-at-login prompt.
- `PopoverViewModel`: app state, action execution, history, settings, and action management.
- `ServerManager`: reuses or starts `apfel` on the first free local port, using `--serve --cors --permissive`.
- `ClipControlServer`: local automation API.
- `FileHistoryStore`: JSON history persistence in Application Support.
- `UserDefaultsSettingsStore`: persistent settings including favorites, hidden actions, saved actions, and preferred panel.
- `PopoverRootView`: fixed-size SwiftUI popover UI.

## Development

```bash
swift build
swift test
make app
make run
make install
make install-cli
./scripts/build-dist.sh
```

The test suite covers:

- content detection
- action catalog behavior
- persistence
- saved custom action flows
- view-model state transitions
- control API behavior
- server startup helpers

## Packaging and distribution

Release packaging lives in the repo:

- `scripts/build-app.sh`: builds the `.app` bundle and embeds `apfel`
- `scripts/build-dist.sh`: creates zip, CLI tarball, Homebrew cask, and checksums
- `scripts/install.sh`: direct installer used by the one-line install path
- `scripts/test-install-methods.sh`: verifies the install paths

If you want a signed + notarized release build, the packaging flow supports it through:

```bash
SIGN_IDENTITY="Developer ID Application: …" \
KEYCHAIN_PROFILE="…" \
./scripts/build-dist.sh
```

Local developer builds do not need that, but they are not the same as a notarized release artifact.

## Related projects

- [apfel](https://github.com/Arthur-Ficial/apfel): CLI and OpenAI-compatible local server for Apple's on-device model
- [apfel-gui](https://github.com/Arthur-Ficial/apfel-gui): native macOS GUI for working with `apfel`

## License

MIT. See [LICENSE](LICENSE).
