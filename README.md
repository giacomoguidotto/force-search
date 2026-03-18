# 🔮 Scry

![MIT License](https://img.shields.io/badge/license-MIT-blue)

Instant search & AI answers in a native floating panel, triggered by force-click or the Globe key, right where you're working.

## 💡 Why

macOS Look Up is slow, limited, and mostly useless. Scry replaces it with real search results and AI answers in a native floating panel, without leaving the app you're in.

## 🔍 Providers

- 🌐 Google, DuckDuckGo, Wikipedia
- 🤖 Claude, OpenAI, Ollama (local, free)

Switch with `Cmd+1-9`. AI providers can also analyze screenshots.

## ⌨️ Shortcuts

| Action               | Shortcut                   |
| -------------------- | -------------------------- |
| Search selected text | Force-click or `Globe` key |
| Switch provider      | `Cmd+1-9`                  |
| Open in browser      | `Cmd+Return`               |
| Copy URL             | `Cmd+C`                    |
| Close panel          | `Esc`                      |

## 🚀 Setup

On first launch, Scry guides you through two steps:

1. **Disable Look Up**, macOS Look Up conflicts with force-click
2. **Accessibility**, needed to read selected text and detect force-click

## 🛠 Build from source

```bash
cd app
xcodegen generate
open Scry.xcodeproj    # then Cmd+R
```

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen). Lint with `swiftlint` (config in `app/.swiftlint.yml`).
