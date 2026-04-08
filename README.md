# apfel-clip

AI-powered clipboard actions from the macOS menu bar, powered by [apfel](https://github.com/Arthur-Ficial/apfel).

Copy text, code, JSON, logs, or shell commands. Hit the menu bar icon or `Cmd+Shift+V`. Choose an action. Paste the result.

Everything stays on-device. No API keys. No cloud model.

## What it does

apfel-clip watches the clipboard and offers tailored actions for what you copied:

- Text: fix grammar, rewrite tone, summarize, bullet points, translate
- Code: explain, find bugs, add comments, simplify
- Errors: explain error, suggest fix
- Shell commands: explain, make safer
- JSON: explain structure, pretty format
- Custom prompts: run your own instruction against the current clipboard

The app now also supports:

- Persistent history and settings
- Favorites and hidden actions via the action manager
- Larger panels for longer clipboard content
- A localhost control API for automation
- Self-contained packaging that can embed `apfel` inside the `.app`

## Requirements

- macOS 26+ (Tahoe)
- Apple Silicon (M1 or later)
- Apple Intelligence enabled

For packaged GitHub/Homebrew app builds, `apfel` can be embedded inside the app bundle.

For raw source builds or direct binaries, apfel-clip falls back to a system `apfel` on `PATH`.

## Install

### GitHub release

```bash
curl -fsSL https://raw.githubusercontent.com/Arthur-Ficial/apfel-clip/main/scripts/install.sh | bash
```

That installs `apfel-clip.app` into `/Applications` and links `apfel-clip` into `~/.local/bin`.

### Homebrew

```bash
brew tap Arthur-Ficial/tap
brew install --cask apfel-clip
```

The generated Homebrew cask is built around the signed GitHub release zip in `dist/homebrew/apfel-clip.rb`.

### Build from source

```bash
git clone https://github.com/Arthur-Ficial/apfel-clip.git
cd apfel-clip
make app
make install-app
make install-cli
```

## Run

- Open `apfel-clip.app`, or
- Run `apfel-clip` from Terminal, or
- Use the menu bar icon once installed

Global hotkey: `Cmd+Shift+V`

## How it works

1. apfel-clip looks for an embedded `apfel` helper first, then falls back to `apfel` on `PATH`
2. It probes for an existing healthy local server and otherwise starts one on a free port
3. It launches `apfel --serve --cors --permissive`
4. It classifies your clipboard content and shows the matching action set
5. It stores successful results in local history and can auto-copy them back to the clipboard

## Packaging and Distribution

The repo now includes:

- `scripts/build-app.sh`: builds `build/apfel-clip.app`
- `scripts/build-dist.sh`: builds GitHub release artifacts and checksums
- `scripts/install.sh`: simple GitHub installer
- `.github/workflows/ci.yml`: build/test/package validation
- `.github/workflows/release.yml`: release artifact automation
- `Packaging/Homebrew/apfel-clip.rb.template`: Homebrew cask template
- `Resources/PrivacyInfo.xcprivacy`: privacy manifest
- `Config/AppStore.entitlements`: App Sandbox entitlements for Mac App Store prep

## App Store Readiness

The repo is prepared for App Store work, but the final submission still depends on Apple-side signing and review artifacts:

- Sign the app with your Mac App Store identity
- Keep `apfel` embedded inside the app bundle for the review build
- Submit the sandboxed, self-contained bundle through App Store Connect

The included files in `Config/` and `Resources/` are the repo-side preparation for that flow.

## Related

- [apfel](https://github.com/Arthur-Ficial/apfel) - CLI and OpenAI-compatible server for Apple's on-device LLM
- [apfel-gui](https://github.com/Arthur-Ficial/apfel-gui) - Native macOS debug GUI for apfel
