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

### 1. Set up the dev environment

This project uses [devenv](https://devenv.sh) to manage development dependencies (xcodegen, gh, Swift toolchain).

```bash
# Install devenv if you don't have it
# https://devenv.sh/getting-started/

# Enter the dev shell
devenv shell
```

### 2. Generate the Xcode project

```bash
cd Scry
xcodegen generate
```

This creates `Scry.xcodeproj` from `project.yml`.

### 3. Build and run

**With Xcode:**

```bash
open Scry.xcodeproj
```

Then hit `Cmd+R` in Xcode.

**With Swift Package Manager** (no Xcode.app required, just Command Line Tools):

```bash
cd Scry
swift build
swift run Scry
```

**With the devenv helper scripts:**

```bash
generate-project   # regenerate .xcodeproj from project.yml
build               # build Debug configuration
test                # run unit tests
clean               # clean build artifacts
```

### 4. Grant permissions

On first launch, Scry will show an onboarding window guiding you through:

1. **Accessibility** — needed to read selected text from any app
2. **Input Monitoring** — needed to detect force-click trackpad gestures

You may need to restart Scry after granting permissions.

### 5. Use it

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

## Building a release DMG

```bash
cd Scry
xcodegen generate
xcodebuild -scheme Scry -configuration Release -derivedDataPath DerivedData build
cd ..
./Scripts/create-dmg.sh 1.0.0
```

The app requires Developer ID signing and notarization for distribution (can't use App Store due to no-sandbox requirement).

## License

[MIT](LICENSE)
