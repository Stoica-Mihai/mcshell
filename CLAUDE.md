# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

mcshell is a Wayland desktop shell (status bar, notifications, OSD, app launcher, quick settings) built entirely in QML using [Quickshell](https://quickshell.outfoxxed.me/) — a Qt6/QML-based shell toolkit for Wayland compositors. It targets the **niri** compositor specifically (workspace/window queries use `niri msg`).

## Running

```sh
./start.sh
# or directly:
qs --path shell.qml
```

The shell requires a running Wayland session with wlr-layer-shell support (niri, Hyprland, Sway, etc.). There is no build step — Quickshell interprets QML directly.

## Architecture

**Entry point:** `shell.qml` — creates a `ShellRoot` containing a `StatusBar` per screen, plus singleton `NotificationPopup`, `OsdOverlay`, and `AppLauncher`.

**Module layout** — each directory is a QML module imported as `qs.<DirName>`:

| Module | Purpose |
|---|---|
| `Config/` | `Theme` singleton — colors (Tokyo Night palette), layout constants, typography. All visual tuning goes here. |
| `Bar/` | `StatusBar` (top bar window) composing: `Workspaces`, `ActiveWindow`, `Clock` (with calendar popup), `Media` (MPRIS), `Network`, `Volume`, `SysTray`, and a quick-settings button. |
| `Notifications/` | DBus notification daemon via `NotificationServer`. `NotificationPopup` manages a `ListModel` of active popups; `NotificationCard` renders each one with urgency-colored accent bar. |
| `OSD/` | `OsdOverlay` — polls `wpctl` and `brightnessctl` every 200ms, shows a center-bottom progress bar on volume/brightness changes (suppressed during startup). |
| `Launcher/` | `AppLauncher` — fullscreen overlay with fuzzy search. Discovers apps via Quickshell's `DesktopEntries` API (falls back to scanning `.desktop` files). |
| `QuickSettings/` | `QuickSettingsPanel` (dropdown `PopupWindow`) with `VolumeSlider` and `ToggleRow` widgets for Wi-Fi, Bluetooth, DND, Night Light. |

**Key patterns:**
- **State via polling:** Most system state (volume, workspaces, network, brightness) is obtained by periodically running CLI tools (`wpctl`, `niri msg`, `nmcli`, `brightnessctl`, `bluetoothctl`) via Quickshell's `Process` + `SplitParser` components, not via persistent IPC connections.
- **Layer shell windows:** All panels use `WlrLayershell` with explicit namespace prefixes (`mcshell`, `mcshell-notifications`, `mcshell-osd`, `mcshell-launcher`, `mcshell-dismiss`).
- **Popup dismissal:** The `StatusBar` creates a fullscreen transparent `PanelWindow` (`clickCatcher`) that appears when any popup is open, catching clicks to dismiss them.
- **Icons:** Uses "Symbols Nerd Font" for all icons (Unicode codepoints, not icon names).
- **No build system:** Pure QML — no C++, no CMake, no npm. Files are loaded by Quickshell at runtime.

## System Dependencies

- **Quickshell** (`qs` binary)
- **niri** compositor (for workspace/window commands)
- **WirePlumber** (`wpctl`) — audio control
- **NetworkManager** (`nmcli`) — network status/toggles
- **brightnessctl** — screen brightness
- **bluetoothctl** — Bluetooth toggling
- **wlsunset** — night light
- **Fonts:** JetBrains Mono, Symbols Nerd Font

## Conventions

- **Native APIs first, CLI fallback only.** Always use QuickShell's built-in service APIs (`Quickshell.Services.Pipewire`, `Quickshell.Services.Mpris`, `Quickshell.Services.SystemTray`, `Quickshell.Services.Notifications`, `Quickshell.Services.UPower`, `Quickshell.Bluetooth`, etc.) before resorting to CLI tools. Native APIs are reactive and instant; CLI polling is laggy. Only use `Process` + CLI tools (`nmcli`, `brightnessctl`, `bluetoothctl`, `niri msg`, etc.) when no native QuickShell API exists. When unsure, check noctalia's implementation at `/etc/xdg/quickshell/noctalia-shell/Services/` for reference.
- All colors and layout constants are centralized in `Config/Theme.qml` — reference `Theme.bg`, `Theme.accent`, etc. rather than hardcoding values.
- QML components use `Quickshell.Io.Process` for system commands — never shell out via Qt's `Qt.createQmlObject` or direct `QProcess`.
- Animations use short durations (80-250ms) with `Easing.OutCubic` or `Easing.InOutQuad`.
- Popup windows (`PopupWindow`) anchor to their trigger widget via `anchor.item` / `anchor.rect`.
- **DRY — extract shared components.** Any UI pattern or logic used more than once must be refactored into a reusable QML component. Never copy-paste slider tracks, toggle rows, popup animations, or similar across files. Example: `SliderTrack.qml` is the single slider implementation used by volume, brightness, and per-app controls.
