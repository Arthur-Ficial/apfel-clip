# apfel-clip

AI-powered clipboard actions from the menu bar - powered by [apfel](https://github.com/Arthur-Ficial/apfel).

Copy any text. Click the menu bar icon. Pick an action. Result goes to your clipboard. Paste.

All on-device. Free. Private. No API keys.

## What it does

A macOS menu bar app that watches your clipboard and offers AI-powered text transformations:

**For text:** Fix grammar, make concise, make formal, make casual, summarize, bullet points, translate (German, French, Spanish, Japanese)

**For code:** Explain, find bugs, add comments, simplify

**For errors:** Explain error, suggest fix

**For shell commands:** Explain command, make safer

**For JSON:** Explain structure, pretty format

Plus **custom prompts** - type your own instruction for any text.

## Requirements

- **macOS 26+** (Tahoe) with Apple Intelligence enabled
- **Apple Silicon** (M1 or later)
- **[apfel](https://github.com/Arthur-Ficial/apfel) must be installed** - apfel-clip needs it to run the server

## Install

### Step 1: Install apfel (the AI server)

```bash
brew tap Arthur-Ficial/tap
brew install apfel
```

### Step 2: Install apfel-clip

**From Homebrew:**

```bash
brew install Arthur-Ficial/tap/apfel-clip
```

**Or build from source:**

```bash
git clone https://github.com/Arthur-Ficial/apfel-clip.git
cd apfel-clip
make install
```

### Step 3: Run

```bash
apfel-clip
```

A clipboard icon appears in your menu bar. That's it.

## How it works

1. apfel-clip starts `apfel --serve` on port 11435 in the background
2. It monitors your clipboard for text changes (polls every 500ms)
3. When you click the icon, it detects the content type (code, error, text, etc.)
4. You pick an action - it sends the text to the local AI server
5. The result auto-copies to your clipboard with a clear "Copied!" banner
6. Paste the result wherever you need it

**Global hotkey:** Cmd+Shift+V toggles the popover from anywhere.

## Features

- **Smart content detection** - shows relevant actions based on what you copied
- **Token budget display** - warns if text is too long for the 4096-token context
- **Auto-copy** - results go straight to your clipboard
- **Before/After view** - compare original and transformed text
- **History** - last 10 transformations, one click to re-copy
- **Custom prompts** - type your own instruction
- **No dock icon** - lives only in the menu bar

## Related

- [apfel](https://github.com/Arthur-Ficial/apfel) - CLI + OpenAI-compatible server for Apple's on-device LLM
- [apfel-gui](https://github.com/Arthur-Ficial/apfel-gui) - Native macOS debug GUI for apfel
