# Scry

macOS menu-bar app that replaces "Look Up" (Force Touch) with instant search in a floating panel. Pure Swift, zero dependencies.

## Project layout

- `Scry/` — Xcode project root (contains `project.yml`, `Package.swift`, source, tests)
- `Scry/Scry/` — app source (App/, Services/, Providers/, UI/, Models/, Utilities/)
- `Scry/ScryTests/` — unit tests
- `.xcodeproj` is **generated** — never edit it by hand, run `xcodegen generate` inside `Scry/`

## Common mistakes

- **`CGEventType.pressure` does not exist.** Use `CGEventType(rawValue: 34)!` for pressure events.
- **`CGPreflightListenEventAccess()` only checks permission** — it does NOT register the app in Input Monitoring. Use `CGRequestListenEventAccess()` to trigger the system prompt.
- **SwiftUI `Color` has no `.tertiaryLabel`** — use `Color(nsColor: .tertiaryLabelColor)`.
- **`NSWindowDelegate` requires `NSObject` base class** — any class conforming to it must inherit from `NSObject`.
- **`ForEach` with `.onMove` needs a `Binding`** — use `ForEach($array)`, not `ForEach(array)`.
- **`NSWorkspace.open(_:withAppBundleIdentifier:...)` is deprecated** since macOS 11. Use `NSWorkspace.openURLs:withApplicationAtURL:configuration:completionHandler:` instead.
- **No Xcode.app on this machine** — only Command Line Tools. Use `swift build` (SPM) locally; `xcodebuild` only works in CI or with full Xcode.

## Build

```sh
cd Scry && swift build          # SPM (works with CLT only)
cd Scry && xcodegen generate    # regenerate .xcodeproj (needs xcodegen)
```

## Architecture

- **SearchProvider protocol** — pluggable backends. Web providers return a URL + CSS/JS injection; native providers (Wikipedia) return `[SearchResult]`.
- **ProviderRegistry** — singleton managing registered/enabled/ordered providers.
- **EventTapService** — CGEventTap with passive NSEvent fallback; publishes force-clicks via Combine.
- **HotKeyService** — Carbon `RegisterEventHotKey`; configurable via `KeyCombo`.
- **AppSettings** — singleton, all `@Published` properties auto-persist to `UserDefaults`. Supports JSON export/import.
- **SearchPanel** — borderless `NSPanel` with `NSVisualEffectView .popover` material. Non-activating.
- **UI is AppKit** (panel, tab bar, search bar) with **SwiftUI for settings/menu bar** only.

## Permissions

The app requires **Accessibility** (`AXIsProcessTrustedWithOptions`) and **Input Monitoring** (`CGRequestListenEventAccess`). No sandbox — entitlements set `com.apple.security.app-sandbox: false`.
