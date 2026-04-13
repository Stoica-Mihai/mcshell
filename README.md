# mcshell

A custom Wayland desktop shell built with [QuickShell](https://quickshell.outfoxxed.me/) for the [niri](https://github.com/YaLTeR/niri) compositor. Pure QML, no build step.

## Screenshots

![Status bar](screenshots/01-bar-hero.png)

| | |
|---|---|
| ![App launcher](screenshots/02-launcher-apps.png) | ![Settings — Theme](screenshots/03-settings-theme.png) |
| ![WiFi networks](screenshots/04-launcher-wifi.png) | ![Bluetooth devices](screenshots/05-launcher-bluetooth.png) |
| ![Calendar with holidays](screenshots/06-calendar.png) | ![Weather forecast](screenshots/07-weather.png) |
| ![Notification history](screenshots/09-notifications.png) | ![System tray](screenshots/10-tray.png) |
| ![System monitor](screenshots/11-sysinfo.png) | ![Keybind hints](screenshots/12-keybinds.png) |

![Wallpaper picker — per-monitor support](screenshots/13-wallpaper-picker.png)

## Features

### Status Bar
Three parallelogram segments (left/center/right) with glass effect and animated accent border (flowing light pulse, breathing, marching dashes, or off — configurable).
- **Workspaces** — animated pills, click to switch, scroll to cycle (native Niri IPC, no polling)
- **Active Window** — reactive title display via Niri IPC
- **Clock** — date + time, left-click for calendar with month/year picker and public holidays for the weather location's country (via [Nager.Date](https://date.nager.at)), right-click for time/date format settings
- **Weather** — current temperature + icon, left-click for forecast dropdown (current conditions, hourly, 5-day), right-click to edit location (inline city search via Open-Meteo geocoding)
- **Recording indicator** — pulsing red dot next to the clock while `wf-recorder` is active
- **Media** — MPRIS controls (prev/play/next), click track title for expanded player with album art, seek bar, live stream detection
- **System Capsule** — WiFi, Bluetooth, Volume, Battery, and the notification bell sharing a single dropdown panel with accent underline on the active icon
  - **WiFi** — native `Quickshell.Networking`, shows connected SSID, left-click opens launcher WiFi tab, middle-click toggles radio
  - **Bluetooth** — native `Quickshell.Bluetooth`, shows connected device + battery, left-click opens launcher Bluetooth tab, middle-click toggles radio
  - **Volume** — PipeWire native, waveform bars visualization, scroll to adjust, middle-click mute, per-app sliders
  - **Battery** — UPower native, icon + percentage, red below 20%, hidden on desktops
  - **Notifications** — unread badge, history list, middle-click for Do Not Disturb, action buttons
- **System Monitor** — CPU core-load waveform bars in the capsule, click to expand dashboard with CPU, RAM, temperatures, disk, network stats (toggleable via Settings > Display)
- **System Tray** — collapsed segmented ring indicator, expand to icon grid with colorized icons, right-click context menus, hover tooltips

### App Launcher
Horizontal filmstrip carousel with parallelogram cards, smooth sliding animation, and animated border on focus (4 styles: midpoint, clockwise, corners, fade — configurable). Three-level keyboard navigation — `view` (search/browse categories), `list` (scroll cards in a tab), `edit` (drill into a selected card, Settings only today) — with each level entered via arrow-Down and exited via Escape. Six tabs:
- **Apps** — fuzzy search, large icon + name + description in expanded view
- **Clipboard** — native clipboard history via Wayland data control protocol, live-updating, text and image support
- **WiFi** — scan and connect to networks, inline password input, signal strength and security display. Ctrl+W to toggle WiFi
- **Bluetooth** — discover, pair, and connect devices with battery display. Ctrl+B to toggle Bluetooth
- **Wallpaper** — browse and apply wallpapers from configured folder, lazy-loaded thumbnails. Per-monitor support: monitor strip shows current wallpaper per screen, Tab to switch target, Enter to apply. Screen badges on cards show which monitors use each wallpaper. Fill mode (crop/fit/stretch/tile), auto-rotation with per-screen targeting, shuffle or sequential order, editable folder path
- **Settings** — audio (device selection, volume), display (brightness, night light + temperature), theme (8 palettes), wallpaper (rotation interval/order/screen, fill mode, folder), power (lock/logout/reboot/shutdown)

### Notifications
- Popup cards with circular donut countdown timer
- Action buttons (Reply, Open, etc.) rendered as pill buttons
- Click anywhere to dismiss, hover to pause countdown
- Screenshot previews in notification body
- History persists across dismissals
- Auto-clean: configurable expiry (30m/1h/6h/24h) removes old notifications automatically
- Do Not Disturb mode suppresses popups (still saves to history)

### Lock Screen
- Wayland session lock protocol (`ext_session_lock_v1`)
- PAM authentication
- 5-second grace period for accidental locks
- Visual dot-per-character password feedback
- Shake animation on failed auth

### Wallpaper
- Native background rendering per screen via layer shell
- Wallpaper picker in the app launcher (Wall tab) with per-monitor support
  - Monitor strip above carousel shows current wallpaper per screen
  - Tab cycles target monitor (All Screens / individual), Enter applies
  - Screen name badges on cards show which monitors use each wallpaper
  - Auto-lands on the focused screen's wallpaper when opening
- Fill mode: crop, fit, stretch, tile (configurable in Settings > Wallpaper)
- Auto-rotation with per-screen targeting (rotate one monitor while another stays static)
- Shuffle or sequential rotation order
- Smooth crossfade transitions when changing wallpapers
- All settings persist to `~/.config/mcshell/settings.json`

### Screenshots
- **Full screen** and **window** capture via native Wayland screencopy (no grim dependency), auto-targets focused monitor on multi-screen setups
- **Area selection** — frozen-frame overlay with drag-to-select, adjustable before confirming with Space
- Copies to clipboard + notification with image preview

### Screen Recording
- Start/stop via `toggleRecording` IPC command
- Auto-detects focused output on multi-monitor
- Pulsing red dot next to clock during recording
- Saves to `~/Videos/`, path added to clipboard history
- Requires `wf-recorder`

### Window Switcher
- Fullscreen overlay with carousel cards (icon + title)
- **Alt+Tab behavior**: niri keybind opens/cycles, release Alt to focus selected window, starts on previous window for quick two-window toggle
- Arrow keys to navigate, Enter to focus, type to filter
- Search bar with parallelogram skew matching card design
- Wrap-around navigation at list boundaries
- Triggered via `toggleWindows` IPC command or Alt+Tab keybind

### Keybind Hints
- Parses `~/.config/niri/config.kdl` for keybindings with live file watching
- Searchable, categorized display with keyboard navigation (apps, workspaces, windows, etc.)

## Running

```sh
make start       # start shell in background
make stop        # stop running shell
make restart     # stop + start
make test        # smoke test: start, run all IPC commands, check for errors/warnings
```

Or manually:
```sh
ln -s /path/to/mcshell ~/.config/quickshell/mcshell
quickshell -c mcshell
```

## IPC Commands

All commands use the format:
```sh
quickshell -c mcshell ipc call mcshell <command>
```

### Launcher

Every `launcherX` IPC accepts two optional positional arguments: `<mode>` and `<target>`.

- `<mode>` is one of `view` / `list` / `edit`. Empty = `view`. Invalid modes log a warning and skip the open.
  - `view` — launcher opens with the search field focused
  - `list` — launcher opens with the card carousel focused (ready to arrow-navigate)
  - `edit` — launcher opens with the currently selected card drilled into (Settings tab only supports `edit` today)
- `<target>` optionally pre-selects an item within the tab before the mode is applied. Each category interprets the string — Settings treats it as a card id (`audio` / `display` / `theme` / `power`).

| Command | Description |
|---|---|
| `toggleLauncher` | Toggle launcher visibility (keeps last state) |
| `launcherApps [mode] [target]` | Open launcher on the Apps tab |
| `launcherClipboard [mode] [target]` | Open launcher on the Clipboard tab |
| `launcherWifi [mode] [target]` | Open launcher on the WiFi tab |
| `launcherBluetooth [mode] [target]` | Open launcher on the Bluetooth tab |
| `launcherWallpaper [mode] [target]` | Open launcher on the Wallpaper tab |
| `launcherSettings [mode] [target]` | Open launcher on the Settings tab. `launcherSettings edit power` drills straight into the power card. |

### Bar Panels

Bar panel IPCs also accept an optional `<mode>` argument (`view` default). Only Weather currently supports a non-view mode (`edit` opens the location search). Invalid modes log a warning and skip the open.

| Command | Description |
|---|---|
| `toggleCalendar [mode]` | Open/close the calendar popup |
| `toggleVolume [mode]` | Open/close the volume panel |
| `toggleNotifications [mode]` | Open/close the notification history |
| `toggleWeather [mode]` | Open/close the weather dropdown. `toggleWeather edit` opens the location editor directly. |
| `toggleClockSettings [mode]` | Open/close the clock settings dropdown (time format, date format, week start) |
| `toggleSysInfo [mode]` | Open/close the system monitor panel (CPU, RAM, temps, disk, network) |
| `toggleKeybinds` | Open/close the keybind hints overlay |

### Session

| Command | Description |
|---|---|
| `lock` | Lock the screen |
| `toggleDnd` | Toggle Do Not Disturb mode |
| `toggleBluetooth` | Toggle Bluetooth on/off |
| `toggleWifi` | Toggle WiFi on/off |

### Wallpaper

| Command | Description |
|---|---|
| `setWallpaper /path/to/image.png` | Set wallpaper on all screens |

### Screenshots

| Command | Description |
|---|---|
| `screenshotFull` | Capture full screen to clipboard (native screencopy) |
| `screenshotArea` | Interactive area selection overlay, Space to confirm |
| `screenshotWindow` | Capture focused window to clipboard (niri) |
| `toggleRecording` | Start/stop screen recording (wf-recorder) |
| `toggleWindows` | Open/close window switcher overlay |
| `clipboardList` | Print clipboard history to stdout |

### Example niri keybinds

```kdl
binds {
    Mod+Q { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "toggleLauncher"; }
    Mod+K { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "toggleKeybinds"; }
    Mod+W { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "launcherWallpaper" "list"; }
    Mod+L { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "lock"; }
    Mod+N { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "launcherWifi"; }
    Mod+B { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "launcherBluetooth"; }
    Ctrl+Alt+Q { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "launcherSettings" "edit power"; }
    Alt+Tab { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "toggleWindows"; }
    Print { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "screenshotArea"; }
    Shift+Print { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "screenshotFull"; }
    Ctrl+Print { spawn "quickshell" "-c" "mcshell" "ipc" "call" "mcshell" "screenshotWindow"; }
}
```

## Bar Interactions

| Widget | Left Click | Middle Click | Right Click | Scroll |
|---|---|---|---|---|
| Workspaces | Switch to workspace | — | — | Cycle workspaces |
| Active Window | Focus window | — | — | — |
| Clock | Toggle calendar | — | Toggle clock settings | — |
| Weather | Toggle forecast | — | Edit location | — |
| Media | Toggle expanded player | — | — | — |
| WiFi (capsule) | Open WiFi launcher tab | Toggle WiFi on/off | — | — |
| Bluetooth (capsule) | Open Bluetooth launcher tab | Toggle Bluetooth on/off | — | — |
| Volume (capsule) | Toggle volume panel | Toggle mute | — | Adjust volume |
| Battery (capsule) | — | — | — | — |
| Bell (capsule) | Toggle notification history | Toggle DND | — | — |
| System Monitor (capsule) | Toggle system info panel (`toggleSysInfo`) | — | — | — |
| Tray Icon | Activate | Secondary activate | Context menu | — |

## Launcher Keyboard Shortcuts

**View (search / category browse):**

| Key | Action |
|---|---|
| ← → | Switch between categories |
| Enter / ↓ | Enter the card carousel (list level) |
| Escape | Close launcher |
| Type | Search + auto-enter list level |

**List (card carousel):**

| Key | Action |
|---|---|
| ← → | Navigate between cards |
| ↓ | Drill into the selected card (edit level — Settings only) |
| Enter | Activate selected card (launch app, copy clip, connect network, apply wallpaper) |
| Escape | Back to view |
| Ctrl+W | Toggle WiFi (WiFi tab) |
| Ctrl+B | Toggle Bluetooth (BT tab) |

**Edit (inside a Settings card):**

| Key | Action |
|---|---|
| ↑ ↓ | Navigate rows inside the card |
| ← → | Adjust the selected row's value |
| Enter | Activate (hold-to-confirm for destructive power actions) |
| Escape | Back to list |

## Dependencies

### Required
| Package | Purpose |
|---|---|
| [Quickshell](https://quickshell.outfoxxed.me/) | 0.2.1+ shell toolkit (`quickshell` binary) |
| [quickshell-plugins](https://github.com/Stoica-Mihai/quickshell-plugins) | Native C++ plugins for Quickshell — see repo for build instructions. Required: `qs-niri-ipc`, `qs-data-control`, `qs-nightlight`, `qs-vibrant-color`, `qs-bt-helper`, `qs-sysinfo`, `qs-networking`, `qs-polkit` |
| [niri](https://github.com/YaLTeR/niri) | Wayland compositor |
| PipeWire + WirePlumber | Audio (native API) |
| NetworkManager | Network status (native API) + `nmcli` for WiFi password connections |
| JetBrains Mono | UI font |
| Symbols Nerd Font | Icon font |

### Optional (features degrade gracefully)
| Package | Purpose |
|---|---|
| `brightnessctl` | Screen brightness control |
| `wf-recorder` | Screen recording |

## Themes

8 built-in palettes + **Auto** (wallpaper-derived). Auto mode extracts the most vibrant color from the current wallpaper using CIELAB chroma analysis and generates a theme from it. Four strategies: Tonal, Vibrant, Neutral, Muted — cycle with left/right arrows. Built-in palettes: Tokyo Night (default), Catppuccin Mocha, Gruvbox Dark, Nord, Dracula, Rosé Pine, Everforest Dark, Catppuccin Latte (light). Switch via Settings > Theme in the launcher. Choice persists across restarts.

## Architecture

Pure QML — no C++, no build system. QuickShell interprets QML directly. Each subdirectory is a module imported as `qs.<DirName>`. For a deeper per-module breakdown see [CLAUDE.md](CLAUDE.md).

| Module | Purpose |
|---|---|
| `Config/` | `Theme` singleton (8 palettes + auto wallpaper theming), `UserSettings` singleton (persistent preferences via `JsonAdapter`, live-reload on external changes) |
| `Core/` | Shared non-visual singletons — `SafeProcess`, `ShellActions` (lock/logout/reboot/shutdown/wallpaper), `Brightness`, `HolidayService` (Nager.Date), `NotificationDispatcher`, `WeatherCodes`, `JsonFetcher`, `ConnectivityRetry`, `OverlayWindow` |
| `Bar/` | Status bar — three parallelogram segments with shared dropdown panels. Left: launcher + workspaces, active window. Center: clock + calendar/clock-settings, weather + forecast/edit (via shared `BarPopupWindow`). Right: media (MPRIS), system tray (collapsed ring + expanded grid), WiFi/BT/volume-waveform/battery/notifications/system-monitor capsule sharing one dropdown. Also `Recording` (wf-recorder driver), `SysInfoPanel` (CPU/RAM/temp/disk/network dashboard) |
| `Launcher/` | App launcher carousel — apps, clipboard, WiFi, Bluetooth, wallpaper, settings tabs with 3-level keyboard navigation (view/list/edit) and lazy-loaded progressive model growth |
| `Notifications/` | DBus notification daemon + popup cards with action buttons |
| `NotificationHistory/` | Notification history dropdown |
| `LockScreen/` | Wayland session lock with PAM auth |
| `Polkit/` | Polkit authentication agent dialog |
| `Wallpaper/` | Background renderer with crossfade transitions, auto-rotation, filesystem scanner |
| `KeybindHints/` | Keybind parser + hints overlay |
| `Screenshot/` | Native screencopy overlay — fullscreen + interactive area selection with crop |
| `WindowSwitcher/` | Window switcher overlay with carousel cards, Alt+Tab behavior, parallelogram search bar |
| `Widgets/` | Shared UI components — `AnimatedPopup`, `AnimatedBorder`, `ParallelogramCard`, `StyledTextField`, `MediaControls`, `ActiveUnderline`, `IconButton`, `TextButton`, `SliderTrack`, `ControlSlider`, `CyclePicker`, `HoverText`, `InfiniteText`, `OptImage`, `Separator`, `ShakeAnimation`, `SmoothWheelHandler`, `ThemedScrollBar`, `ThemedTooltip`, `TriToggle` |

## Acknowledgements

- [skwd](https://github.com/liixini/skwd) by liixini — the parallelogram card design and carousel-based launcher concept that inspired mcshell's visual direction

## License

See [LICENSE](LICENSE).
