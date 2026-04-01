# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

mcshell is a Wayland desktop shell (status bar, notifications, app launcher, quick settings) built entirely in QML using [Quickshell](https://quickshell.outfoxxed.me/) — a Qt6/QML-based shell toolkit for Wayland compositors. It targets the **niri** compositor specifically via the native `Quickshell.Niri` IPC module.

## Running

```sh
./start.sh
# or directly:
qs --path shell.qml
```

The shell requires a running Wayland session with wlr-layer-shell support (niri, Hyprland, Sway, etc.). There is no build step — Quickshell interprets QML directly.

## Architecture

**Entry point:** `shell.qml` — creates a `ShellRoot` containing a `StatusBar` per screen, plus singleton `NotificationPopup`, `AppLauncher`, `KeybindPanel`, `LockScreen`, `WallpaperRenderer`, and `WallpaperPicker`.

**Module layout** — each directory is a QML module imported as `qs.<DirName>`:

| Module | Purpose |
|---|---|
| `Config/` | `Theme` singleton — colors (Tokyo Night palette), layout constants, typography, icon codepoints. All visual tuning goes here. |
| `Core/` | Non-visual shared components — `SafeProcess` and `SafePolledProcess` (process wrappers with error logging). |
| `Bar/` | `StatusBar` (top bar window) composing: `Workspaces`, `ActiveWindow`, `Clock` (with calendar popup), `Media` (MPRIS), `Network`, `Volume`, `SysTray`, and a system capsule with quick-settings dropdown. |
| `Notifications/` | DBus notification daemon via `NotificationServer`. `NotificationPopup` manages a `ListModel` of active popups; `NotificationCard` renders each one with urgency-colored accent bar and action buttons. |
| `OSD/` | `OsdOverlay` — volume/brightness on-screen display. |
| `Launcher/` | `AppLauncher` — fullscreen overlay with fuzzy search and 5 tabs: Apps, Clipboard, Notifications, WiFi, Bluetooth. Uses `CarouselStrip` for shared card layout and `DisabledCard` for off-state cards. |
| `QuickSettings/` | `QuickSettingsPanel` (dropdown `PopupWindow`) with `VolumeSlider`, brightness slider, night light toggle, and power actions. |
| `LockScreen/` | Wayland session lock (`ext_session_lock_v1`) with PAM authentication. |
| `Wallpaper/` | Background renderer per screen with crossfade transitions, carousel picker, and persistent config. |
| `KeybindHints/` | Parses `~/.config/niri/config.kdl` for keybindings, searchable overlay. |
| `NotificationHistory/` | Notification history dropdown in the bar. |
| `Widgets/` | Shared UI components — `AnimatedPopup`, `IconButton`, `PolledProcess`. |

**Key patterns:**
- **Native APIs first:** Workspaces and active window use `Quickshell.Niri` (reactive, event-driven via niri IPC socket). Network status uses `Quickshell.Networking`. Audio uses `Quickshell.Services.Pipewire`. Media uses `Quickshell.Services.Mpris`. System tray uses `Quickshell.Services.SystemTray`. Bluetooth uses `Quickshell.Bluetooth`. CLI tools (`brightnessctl`, `wlsunset`, `nmcli`, `grim`, `slurp`) are only used where no native API exists.
- **Error handling:** All subprocess calls use `SafeProcess` / `SafePolledProcess` from `Core/`, which log failures to console with descriptive messages and emit `failed()` / `finished()` signals.
- **Layer shell windows:** All panels use `WlrLayershell` with explicit namespace prefixes (`mcshell`, `mcshell-notifications`, `mcshell-osd`, `mcshell-launcher`, `mcshell-dismiss`).
- **Popup dismissal:** The `StatusBar` creates a fullscreen transparent `PanelWindow` (`clickCatcher`) that appears when any popup is open, catching clicks to dismiss them.
- **Icons:** Uses "Symbols Nerd Font" for all icons (Unicode codepoints, not icon names).
- **No build system:** Pure QML — no C++, no CMake, no npm. Files are loaded by Quickshell at runtime.

## System Dependencies

- **Quickshell** (`qs` binary) with `Quickshell.Niri` module
- **niri** compositor
- **PipeWire + WirePlumber** — audio (native API)
- **NetworkManager** — network status (native API) + `nmcli` for WiFi connect with password
- **brightnessctl** — screen brightness
- **wlsunset** — night light
- **grim** + **slurp** + **wl-copy** — screenshots
- **cliphist** — clipboard history
- **Fonts:** JetBrains Mono, Symbols Nerd Font

## Conventions

- **Native APIs first, CLI fallback only.** Always use QuickShell's built-in service APIs (`Quickshell.Niri`, `Quickshell.Services.Pipewire`, `Quickshell.Services.Mpris`, `Quickshell.Services.SystemTray`, `Quickshell.Services.Notifications`, `Quickshell.Services.UPower`, `Quickshell.Bluetooth`, `Quickshell.Networking`, etc.) before resorting to CLI tools. Native APIs are reactive and instant; CLI polling is laggy. Only use `SafeProcess` + CLI tools when no native QuickShell API exists. When unsure, check noctalia's implementation at `/etc/xdg/quickshell/noctalia-shell/Services/` for reference.
- All colors and layout constants are centralized in `Config/Theme.qml` — reference `Theme.bg`, `Theme.accent`, etc. rather than hardcoding values.
- All subprocess calls must use `SafeProcess` or `SafePolledProcess` from `Core/` — never raw `Process` without error handling.
- Animations use short durations (80-250ms) with `Easing.OutCubic` or `Easing.InOutQuad`.
- Popup windows (`PopupWindow`) anchor to their trigger widget via `anchor.item` / `anchor.rect`.
- **DRY — extract shared components first.** Any UI pattern or logic used more than once must be refactored into a reusable QML component BEFORE duplicating it. Write the shared component first, then use it. Never copy-paste then refactor later. Example: `CarouselStrip.qml` is the single carousel card implementation used by all 5 launcher tabs.
- **Disabled/muted state convention:** When a feature is disabled (volume muted, DND active), its icon must be red (`Theme.red`) with a slashed variant. Red takes priority over hover color — never let hover override the disabled state.
- **Keyboard-first design.** mcshell targets niri's keyboard-driven paradigm. Interactive features should be controllable via keybinds, not require mouse clicks. Buttons are a last resort — prefer keybind hints in the UI.
