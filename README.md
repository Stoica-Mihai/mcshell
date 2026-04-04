# mcshell (WIP)

A custom Wayland desktop shell built with [QuickShell](https://quickshell.outfoxxed.me/) for the [niri](https://github.com/YaLTeR/niri) compositor. Pure QML, no build step.

## Features

### Status Bar
- **Workspaces** — animated pills, click to switch, scroll to cycle (native Niri IPC, no polling)
- **Active Window** — reactive title display via Niri IPC
- **Clock** — date + time, click for calendar with month/year picker
- **Media** — MPRIS controls (prev/play/next), click track title for expanded player with album art, seek bar, live stream detection
- **System Capsule** — grouped volume, battery, notifications, and settings icons sharing a single dropdown panel with accent underline on the active icon
  - **Volume** — PipeWire native, scroll to adjust, middle-click mute, per-app sliders
  - **Battery** — UPower native, icon + percentage, red below 20%, hidden on desktops
  - **Notifications** — unread badge, history list, middle-click for Do Not Disturb, action buttons
  - **Quick Settings** — power menu (lock/logout/reboot/shutdown), brightness slider, night light toggle
- **Network** — reactive status via native Networking API
- **System Tray** — colorized icons, right-click context menus, hover tooltips

### App Launcher
Horizontal filmstrip carousel with smooth sliding animation. Two-level keyboard navigation: Left/Right to switch categories (Level 1), Enter to dive in, Left/Right to navigate cards (Level 2), Escape to go back. Six tabs:
- **Apps** — fuzzy search, large icon + name + description in expanded view
- **Clipboard** — native clipboard history via Wayland data control protocol, live-updating, text and image support
- **WiFi** — scan and connect to networks, inline password input, signal strength and security display. Ctrl+W to toggle WiFi
- **Bluetooth** — discover, pair, and connect devices with battery display. Ctrl+B to toggle Bluetooth
- **Wallpaper** — browse and apply wallpapers from configured folder, lazy-loaded thumbnails, active wallpaper highlighted
- **Settings** — audio (device selection, volume), display (brightness, night light + temperature), theme (8 palettes), power (lock/logout/reboot/shutdown)

### Notifications
- Popup cards with circular donut countdown timer
- Action buttons (Reply, Open, etc.) rendered as pill buttons
- Click anywhere to dismiss, hover to pause countdown
- Screenshot previews in notification body
- History persists across dismissals
- Do Not Disturb mode suppresses popups (still saves to history)

### Lock Screen
- Wayland session lock protocol (`ext_session_lock_v1`)
- PAM authentication
- 5-second grace period for accidental locks
- Visual dot-per-character password feedback
- Shake animation on failed auth

### Wallpaper
- Native background rendering per screen via layer shell
- Wallpaper picker integrated in the app launcher (Wall tab)
- Smooth crossfade transitions when changing wallpapers
- All settings persist to `~/.config/mcshell/settings.json`

### Screenshots
- **Full screen** and **window** capture via native Wayland screencopy (no grim dependency)
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
- Arrow keys to navigate, Enter to focus, type to filter
- Triggered via `toggleWindows` IPC command

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
qs -c mcshell
```

## IPC Commands

All commands use the format:
```sh
qs -c mcshell ipc call mcshell <command>
```

### Launcher

| Command | Description |
|---|---|
| `toggleLauncher` | Open/close the app launcher carousel |
| `launcherApps` | Open launcher on the Apps tab |
| `launcherClipboard` | Open launcher on the Clipboard tab |
| `launcherWifi` | Open launcher on the WiFi tab |
| `launcherBluetooth` | Open launcher on the Bluetooth tab |
| `launcherWallpaper` | Open launcher on the Wallpaper tab |
| `launcherSettings` | Open launcher on the Settings tab |

### Bar Panels

| Command | Description |
|---|---|
| `toggleCalendar` | Open/close the calendar popup |
| `toggleVolume` | Open/close the volume panel |
| `toggleNotifications` | Open/close the notification history |
| `toggleSettings` | Open/close the quick settings panel |
| `toggleKeybinds` | Open/close the keybind hints overlay |
| `toggleWallpaper` | Open launcher on the Wallpaper tab |

### Session

| Command | Description |
|---|---|
| `lock` | Lock the screen |
| `toggleDnd` | Toggle Do Not Disturb mode |

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
    Mod+Q { spawn "qs" "-c" "mcshell" "ipc" "call" "mcshell" "toggleLauncher"; }
    Mod+K { spawn "qs" "-c" "mcshell" "ipc" "call" "mcshell" "toggleKeybinds"; }
    Mod+W { spawn "qs" "-c" "mcshell" "ipc" "call" "mcshell" "toggleWallpaper"; }
    Mod+L { spawn "qs" "-c" "mcshell" "ipc" "call" "mcshell" "lock"; }
    Mod+N { spawn "qs" "-c" "mcshell" "ipc" "call" "mcshell" "launcherWifi"; }
    Mod+B { spawn "qs" "-c" "mcshell" "ipc" "call" "mcshell" "launcherBluetooth"; }
    Print { spawn "qs" "-c" "mcshell" "ipc" "call" "mcshell" "screenshotArea"; }
    Shift+Print { spawn "qs" "-c" "mcshell" "ipc" "call" "mcshell" "screenshotFull"; }
    Ctrl+Print { spawn "qs" "-c" "mcshell" "ipc" "call" "mcshell" "screenshotWindow"; }
}
```

## Bar Interactions

| Widget | Left Click | Middle Click | Right Click | Scroll |
|---|---|---|---|---|
| Workspaces | Switch to workspace | — | — | Cycle workspaces |
| Active Window | Focus window | — | — | — |
| Clock | Toggle calendar | — | — | — |
| Media | Toggle expanded player | — | — | — |
| Volume (capsule) | Toggle volume panel | Toggle mute | — | Adjust volume |
| Battery (capsule) | — | — | — | — |
| Bell (capsule) | Toggle notification history | Toggle DND | — | — |
| Settings (capsule) | Toggle quick settings | — | — | — |
| Tray Icon | Activate | Secondary activate | Context menu | — |

## Launcher Keyboard Shortcuts

**Level 1 (Category browse):**

| Key | Action |
|---|---|
| ← → | Switch between categories |
| Enter / ↓ | Enter category (Level 2) |
| Escape | Close launcher |
| Type | Search + auto-enter Level 2 |

**Level 2 (Inside category):**

| Key | Action |
|---|---|
| ← → | Navigate between cards |
| Enter | Activate selected card (launch app, copy clip, connect network, apply wallpaper) |
| Escape | Back to Level 1 |
| Ctrl+W | Toggle WiFi (WiFi tab) |
| Ctrl+B | Toggle Bluetooth (BT tab) |

## Dependencies

### Required
| Package | Purpose |
|---|---|
| [mcs-qs](https://github.com/Stoica-Mihai/mcs-qs) | Quickshell fork with Niri IPC, clipboard history, night light, VibrantColor (`qs` binary) |
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

Pure QML — no C++, no build system. QuickShell interprets QML directly. Each subdirectory is a module imported as `qs.<DirName>`.

| Module | Purpose |
|---|---|
| `Config/` | Theme singleton (8 palettes + auto wallpaper theming), UserSettings singleton (persistent preferences via JsonAdapter) |
| `Core/` | Shared non-visual components — SafeProcess, SafePolledProcess, LazyModel |
| `Bar/` | Status bar — workspaces (Niri IPC), active window, clock + calendar, media, network, volume, battery, system tray |
| `Launcher/` | App launcher carousel — apps, clipboard, notifications, WiFi, Bluetooth, wallpaper, settings tabs |
| `Notifications/` | Notification daemon + popup cards with action buttons |
| `NotificationHistory/` | Notification history dropdown |
| `QuickSettings/` | Quick settings panel — brightness, night light, power actions |
| `LockScreen/` | Wayland session lock with PAM auth |
| `Wallpaper/` | Background renderer with crossfade transitions |
| `KeybindHints/` | Keybind parser + hints overlay |
| `Screenshot/` | Native screencopy overlay — fullscreen + interactive area selection with crop |
| `WindowSwitcher/` | Fullscreen window switcher overlay with carousel cards |
| `Widgets/` | Shared UI components — AnimatedPopup, IconButton, SliderTrack, ControlSlider |

## License

See [LICENSE](LICENSE).
