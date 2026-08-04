# Promptbar

A tiny macOS menu bar app that keeps your prompts one keystroke away. Native SwiftUI, no dependencies, and your data never leaves a local JSON file.

Hit <kbd>⌥⌘P</kbd> from any app, type a couple of letters, press return — the prompt is on your clipboard.

![Quick panel](assets/quick-panel.png)

## What it does

- Lives in the menu bar. No Dock icon, no windows getting in your way.
- Spotlight-style quick panel on a global hotkey (<kbd>⌥⌘P</kbd> by default, configurable). Arrow keys to move, return to copy and dismiss, esc to close.
- Pin the prompts you use most so they always show up first.
- Search, create, edit and delete from the menu bar popover — or open it as a regular window if you prefer.
- Import and export your prompts as JSON.
- Launch at login, choose the menu bar icon, toggle text previews.

Prompts are stored in `~/Library/Application Support/Promptbar/prompts.json`. No accounts, no sync, no telemetry.

<img src="assets/main-window.png" width="420" alt="Main window">

## Installing

Requires macOS 14 (Sonoma) or later.

Grab `Promptbar.zip` from the [latest release](https://github.com/manurrdd/promptbar/releases/latest), unzip it and move `Promptbar.app` to `/Applications`.

The app is not notarized (there's no paid developer account behind this), so the first launch needs one extra step: right-click the app and choose *Open*, or if macOS still refuses, clear the quarantine flag:

```bash
xattr -d com.apple.quarantine /Applications/Promptbar.app
```

If you'd rather not trust a downloaded binary, building it yourself takes a minute — see below.

## Building from source

You need Swift 5.9+, which comes with Xcode or the Command Line Tools.

```bash
git clone https://github.com/manurrdd/promptbar.git
cd promptbar
swift run
```

The icon shows up in your menu bar. To install your own build:

```bash
./make-app.sh
mv Promptbar.app /Applications
open /Applications/Promptbar.app
```

Note that "Launch at login" only works when Promptbar runs as an installed app, not through `swift run`.

To quit, use the ⏻ button at the bottom of the menu bar popover.

## Code layout

Everything is plain SwiftUI/AppKit under `Sources/Promptbar/`. The interesting bits: `QuickPanel.swift` implements the floating panel as a non-activating `NSPanel`, so it can appear over any app without stealing focus, and `HotKey.swift` registers the global shortcut through Carbon, which still is the simplest way to get a system-wide hotkey without asking for accessibility permissions.

## License

[MIT](LICENSE)
