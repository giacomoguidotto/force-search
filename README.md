# 🔮 Scry

Instant search & AI answers in a native floating panel — triggered by force-click or the Globe key, right where you're working.

**[Download](https://scry.guidotto.dev)** · macOS 13+

![MIT License](https://img.shields.io/badge/license-MIT-blue)

## ✨ What it does

Select text anywhere on your Mac, then **force-click** or tap the **Globe key** — a floating panel appears with search results or AI answers. No app-switching, no browser tabs.

## 🔍 Providers

| Web        | AI                   |
| ---------- | -------------------- |
| Google     | Claude               |
| DuckDuckGo | OpenAI               |
| Wikipedia  | Ollama (local, free) |

Switch between them with `Cmd+1/2/3`. AI providers can also analyze screenshots.

## ⌨️ Shortcuts

| Action               | Shortcut                     |
| -------------------- | ---------------------------- |
| Search selected text | Force-click or `Globe` key    |
| Switch provider      | `Cmd+1/2/3`                  |
| Open in browser      | `Cmd+Return`                 |
| Copy URL             | `Cmd+C`                      |
| Close panel          | `Esc`                        |

## 🚀 Setup

On first launch, Scry guides you through three steps:

1. **Disable Look Up** — macOS Look Up conflicts with force-click
2. **Accessibility** — needed to read selected text
3. **Input Monitoring** — needed to detect force-click

## 🛠 Build from source

```bash
cd app
xcodegen generate
open Scry.xcodeproj    # then Cmd+R
```

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen). Lint with `swiftlint` (config in `app/.swiftlint.yml`).
