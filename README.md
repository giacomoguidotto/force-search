# Scry

Replace macOS's useless "Look Up" (Force Touch / Siri Knowledge) with instant Google search in a native floating panel, right where you force-clicked.

## Features

- **Force Click to search** — force-click any selected text to instantly search it
- **Global hotkey** — `Cmd+Shift+G` (configurable) to search selected text from anywhere
- **Multiple search providers** — Google, DuckDuckGo, Wikipedia — switchable with `Cmd+1/2/3`
- **Editable search bar** — refine your query without re-triggering
- **Native floating panel** — frosted glass, non-activating, doesn't steal focus
- **Keyboard-first UX** — `Esc` to close, `Cmd+Return` to open in browser, `Cmd+C` to copy URL
- **Physics-based animations** — spring/ease curves, Raycast-inspired
- **Fully configurable** — panel size, opacity, theme, providers, hotkey, pressure sensitivity
- **Settings import/export** — JSON-based, portable between machines
- **Zero dependencies** — Apple frameworks only (AppKit, WebKit, SwiftUI, Carbon, etc.)

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission (to read selected text)
- Input Monitoring permission (to detect force-click)

## Getting started

### 1. Build and run

**With Swift Package Manager** (no Xcode.app required, just Command Line Tools):

```bash
cd Scry
swift build
swift test
```

**With Xcode** (if installed):

```bash
cd Scry
xcodegen generate   # regenerate .xcodeproj from project.yml
open Scry.xcodeproj
```

Then hit `Cmd+R` in Xcode.

### 2. Grant permissions

On first launch, Scry will show an onboarding window guiding you through:

1. **Disable Look Up** — macOS Look Up uses force-click by default, which conflicts with Scry. Change it to three-finger tap or disable it.
2. **Accessibility** — needed to read selected text from any app
3. **Input Monitoring** — needed to detect force-click trackpad gestures

You may need to restart Scry after granting permissions.

### 3. Use it

- **Select text** in any app, then **force-click** (press hard on trackpad) → search panel appears
- Or press **Cmd+Shift+G** with text selected
- **Edit the query** in the search bar, press Return to re-search
- **Switch providers** with `Cmd+1` (Google), `Cmd+2` (DuckDuckGo), `Cmd+3` (Wikipedia)
- **Cmd+Return** to open results in your browser
- **Escape** or click outside to dismiss

## Configuration

Open Preferences from the menu bar icon:

| Tab | Settings |
|---|---|
| **General** | Theme (system/light/dark), animations, panel size/opacity, launch at login |
| **Providers** | Enable/disable providers, drag to reorder, set default |
| **Shortcuts** | Global hotkey recorder, force-click sensitivity, keyboard reference |

Settings can be exported/imported as JSON via the `...` menu in Preferences.

## Architecture

```
Scry/
├── App/              # Entry point, AppDelegate coordinator
├── Services/         # EventTap, TextExtractor, HotKey, Permissions
├── Providers/        # SearchProvider protocol + Google, DuckDuckGo, Wikipedia
├── UI/               # SearchPanel (AppKit), Preferences (SwiftUI), Onboarding
├── Models/           # AppSettings, KeyCombo, PanelAppearance enums
└── Utilities/        # Constants, animation presets, NSScreen extensions
```

**Adding a new search provider:** implement the `SearchProvider` protocol and register it in `ProviderRegistry`. Web-based providers just return a URL + optional CSS/JS injection. Native providers return `[SearchResult]` for AppKit rendering.

## Linting

The project uses [SwiftLint](https://github.com/realm/SwiftLint) for code style enforcement:

```bash
cd Scry
swiftlint          # lint all source files
swiftlint --fix    # auto-fix where possible
```

Configuration is in `Scry/.swiftlint.yml`.

## License

[MIT](LICENSE)
