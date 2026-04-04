# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

mcshell is a Wayland desktop shell (status bar, notifications, app launcher, quick settings) built entirely in QML using [Quickshell](https://quickshell.outfoxxed.me/) — a Qt6/QML-based shell toolkit for Wayland compositors. It targets the **niri** compositor specifically via the native `Quickshell.Niri` IPC module.

## Running

```sh
make start       # start shell in background
make stop        # stop running shell
make restart     # stop + start
make test        # smoke test: start shell, run all IPC commands, check for errors/warnings
```

Or directly: `./start.sh` / `qs --path shell.qml`

The shell requires a running Wayland session with wlr-layer-shell support (niri, Hyprland, Sway, etc.). There is no build step — Quickshell interprets QML directly.

## Architecture

**Entry point:** `shell.qml` — creates a `ShellRoot` containing a `StatusBar` per screen, plus singleton `NotificationPopup`, `AppLauncher`, `KeybindPanel`, `LockScreen`, `WallpaperRenderer`, `ScreenshotOverlay`, and `PolkitDialog`.

**Module layout** — each directory is a QML module imported as `qs.<DirName>`:

| Module | Purpose |
|---|---|
| `Config/` | `Theme` singleton — colors (Tokyo Night palette), layout constants, typography, icon codepoints. `UserSettings` singleton — persistent user preferences (`~/.config/mcshell/settings.json`) via `FileView` + `JsonAdapter`. |
| `Core/` | Non-visual shared components — `SafeProcess`, `SafePolledProcess` (process wrappers with error logging), `LazyModel` (windowed model for large arrays). |
| `Bar/` | `StatusBar` (top bar window) composing: `Workspaces`, `ActiveWindow`, `Clock` + `CalendarPopup`, `Media` (MPRIS), `Network`, `Volume`, `Battery`, `SysTray`, and a system capsule (`CapsuleItem`) with quick-settings dropdown. |
| `Notifications/` | DBus notification daemon via `NotificationServer`. `NotificationPopup` manages a `ListModel` of active popups; `NotificationCard` renders each one with urgency-colored accent bar and action buttons. |
| `OSD/` | `OsdOverlay` — volume/brightness on-screen display. |
| `Launcher/` | `AppLauncher` — generic fullscreen carousel container. Each tab is a `LauncherCategory` component (`CategoryApps`, `CategoryClipboard`, `CategoryWifi`, `CategoryBluetooth`, `CategoryWallpaper`, `CategorySettings`). Shared components: `CarouselStrip` (card layout with `focused` border), `DisabledCard` (off/scanning states), `SettingsCard` (data-driven settings sub-routing), `SettingsRow` (highlighted row for settings panels), `LazyModel` (windowed loading for large lists). |
| `QuickSettings/` | `QuickSettingsPanel` (dropdown `PopupWindow`) with `VolumeSlider`, brightness slider, night light toggle, and power actions. |
| `LockScreen/` | Wayland session lock (`ext_session_lock_v1`) with PAM authentication. |
| `Wallpaper/` | Background renderer per screen with crossfade transitions. Wallpaper picker is in `Launcher/CategoryWallpaper`. |
| `KeybindHints/` | `KeybindParser` (KDL config parser) + `KeybindPanel` (searchable overlay UI). |
| `NotificationHistory/` | Notification history dropdown in the bar. |
| `Screenshot/` | `ScreenshotOverlay` — native Wayland screencopy for fullscreen + interactive area selection with crop. Always-visible PanelWindow (WlrLayershell destroys QQuickWindow on hide); uses `mask: Region {}` + `opacity: 0` for idle state. |
| `Widgets/` | Shared UI components — `AnimatedPopup`, `IconButton`, `PolledProcess`, `SliderTrack`, `ControlSlider`. |

**Key patterns:**
- **Native APIs first:** Workspaces and active window use `Quickshell.Niri` (reactive, event-driven via niri IPC socket). Network status uses `Quickshell.Networking`. Audio uses `Quickshell.Services.Pipewire`. Media uses `Quickshell.Services.Mpris`. System tray uses `Quickshell.Services.SystemTray`. Bluetooth uses `Quickshell.Bluetooth`. Battery uses `Quickshell.Services.UPower`. Screenshots use `Quickshell.Wayland.ScreencopyView` (native Wayland screencopy). Clipboard history uses `Quickshell.Wayland._DataControl` (native `ext-data-control-v1`). Night light uses `Quickshell.Wayland._GammaControl` (native `zwlr-gamma-control-v1`). CLI tools (`brightnessctl`, `nmcli`) are only used where no native API exists.
- **Error handling:** All subprocess calls use `SafeProcess` / `SafePolledProcess` from `Core/`, which log failures to console with descriptive messages and emit `failed()` / `finished()` signals.
- **Layer shell windows:** All panels use `WlrLayershell` with explicit namespace prefixes (`mcshell`, `mcshell-notifications`, `mcshell-osd`, `mcshell-launcher`, `mcshell-screenshot`, `mcshell-dismiss`).
- **Popup dismissal:** The `StatusBar` creates a fullscreen transparent `PanelWindow` (`clickCatcher`) that appears when any popup is open, catching clicks to dismiss them.
- **Icons:** Uses "Symbols Nerd Font" for all icons (Unicode codepoints, not icon names).
- **No build system:** Pure QML — no C++, no CMake, no npm. Files are loaded by Quickshell at runtime.

## System Dependencies

- **[noctalia-qs](https://github.com/noctalia-dev/noctalia-qs)** — Quickshell fork with `Quickshell.Niri` module (`qs` binary)
- **niri** compositor
- **PipeWire + WirePlumber** — audio (native API)
- **NetworkManager** — network status (native API) + `nmcli` for WiFi connect with password
- **brightnessctl** — screen brightness
- **Fonts:** JetBrains Mono, Symbols Nerd Font

## Conventions

- **Native APIs first, CLI fallback only.** Always use QuickShell's built-in service APIs (`Quickshell.Niri`, `Quickshell.Services.Pipewire`, `Quickshell.Services.Mpris`, `Quickshell.Services.SystemTray`, `Quickshell.Services.Notifications`, `Quickshell.Services.UPower`, `Quickshell.Bluetooth`, `Quickshell.Networking`, etc.) before resorting to CLI tools. Native APIs are reactive and instant; CLI polling is laggy. Only use `SafeProcess` + CLI tools when no native QuickShell API exists. When unsure, check noctalia's implementation at `/etc/xdg/quickshell/noctalia-shell/Services/` for reference.
- All colors and layout constants are centralized in `Config/Theme.qml` — reference `Theme.bg`, `Theme.accent`, `Theme.overlay`, `Theme.backdrop`, etc. rather than hardcoding `Qt.rgba()` values.
- All subprocess calls must use `SafeProcess` or `SafePolledProcess` from `Core/` — never raw `Process` without error handling.
- Animation durations use Theme constants: `Theme.animFast` (100ms, hover), `Theme.animNormal` (150ms, state changes), `Theme.animSmooth` (200ms, transitions), `Theme.animCarousel` (350ms, carousel). Never hardcode duration values.
- **Large list performance:** Use `Core/LazyModel` with a numeric Repeater model for categories with potentially hundreds of items (clipboard, wallpaper). This avoids creating all delegates at once. The `LazyModel` exposes a `count` that grows as the user navigates.
- Popup windows (`PopupWindow`) anchor to their trigger widget via `anchor.item` / `anchor.rect`.
- **DRY — no exceptions.**
  - **Extract shared components BEFORE using them.** If a pattern will be used more than once, write the shared component first, then use it everywhere. Never copy-paste and "refactor later."
  - **New features must use existing patterns.** Before writing any new code, check how existing similar features work. If the launcher has 5 tabs that all use a Repeater + CarouselStrip inside slidingRow, the 6th tab must use the same pattern — not a separate Row with custom positioning.
  - **Make the system generic, not special-cased.** If adding a new feature requires `if (feature === X)` branches in shared code, the architecture is wrong. Instead, define an interface that all features implement, and have the shared code dispatch generically. Example: `LauncherCategory.qml` defines the interface; each tab implements it; `AppLauncher.qml` uses `activeCategory.model` instead of `if (activeTab === 0) filteredApps else if...`.
  - **Hardcoded indices are a code smell.** `categories[1].clipboardLoaded` breaks when tabs are reordered. Use properties on the active category instead.
  - **Key examples:** `CarouselStrip.qml` is the single card implementation for all launcher tabs. `LauncherCategory.qml` is the base interface for all tab categories. `DisabledCard.qml` is shared across WiFi-off, BT-off, and scanning states. `CapsuleItem.qml` is the shared icon+label pattern in the bar capsule. `SettingsRow.qml` is the shared row for all settings panels. `SafeProcess.qml` wraps all subprocess calls.
- **Disabled/muted state convention:** When a feature is disabled (volume muted, DND active), its icon must be red (`Theme.red`) with a slashed variant. Red takes priority over hover color — never let hover override the disabled state.
- **Keyboard-first design.** mcshell targets niri's keyboard-driven paradigm. Interactive features should be controllable via keybinds, not require mouse clicks. Buttons are a last resort — prefer keybind hints in the UI.
- **Verify before handing off.** Before presenting changes for testing, always run `qs -c mcshell` (or reload the shell) and verify that the code at minimum loads without errors. Check QML console output for warnings. If the shell doesn't load, fix it — don't hand broken code to the user. When refactoring, verify that existing functionality still works: tabs switch, cards render, keyboard shortcuts respond.
