# mcshell

A custom Wayland desktop shell built with [QuickShell](https://quickshell.outfoxxed.me/) for the [niri](https://github.com/YaLTeR/niri) compositor. Pure QML, no build step.

## Features

### Status Bar
- **Workspaces** — animated pills, click to switch, scroll to cycle (native Niri IPC, no polling)
- **Active Window** — reactive title display via Niri IPC
- **Clock** — date + time, click for calendar with month/year picker
- **Media** — MPRIS controls (prev/play/next), click track title for expanded player with album art, seek bar, live stream detection
- **System Capsule** — grouped volume, notifications, and settings icons sharing a single dropdown panel with accent underline on the active icon
  - **Volume** — PipeWire native, scroll to adjust, middle-click mute, per-app sliders
  - **Notifications** — unread badge, history list, middle-click for Do Not Disturb, action buttons
  - **Quick Settings** — power menu (lock/logout/reboot/shutdown), brightness slider, night light toggle
- **Network** — reactive status via native Networking API
- **System Tray** — colorized icons, right-click context menus, hover tooltips

### App Launcher
Horizontal filmstrip carousel with smooth sliding animation. Five tabs:
- **Apps** — fuzzy search, large icon + name + description in expanded view
- **Clipboard** — cliphist integration, image entry detection with metadata display
- **Notifications** — browse past notifications with search
- **WiFi** — scan and connect to networks, inline password input, signal strength and security display. Press W to toggle WiFi on/off
- **Bluetooth** — discover, pair, and connect devices with battery display. Press B to toggle Bluetooth on/off

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
- Carousel picker with horizontal filmstrip (same animation as app launcher)
- Smooth crossfade transitions when changing wallpapers
- Config persistence to `~/.config/mcshell/wallpaper.json`

### Screenshots
- Full screen, area selection (slurp), and window capture
- Copies to clipboard + saves to temp file
- Notification with image preview on capture

### Keybind Hints
- Parses `~/.config/niri/config.kdl` for keybindings
- Searchable, categorized display (apps, workspaces, windows, etc.)

## Running

```sh
./start.sh
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
| `launcherNotifications` | Open launcher on the Notifications tab |
| `launcherWifi` | Open launcher on the WiFi tab |
| `launcherBluetooth` | Open launcher on the Bluetooth tab |

### Bar Panels

| Command | Description |
|---|---|
| `toggleCalendar` | Open/close the calendar popup |
| `toggleVolume` | Open/close the volume panel |
| `toggleNotifications` | Open/close the notification history |
| `toggleSettings` | Open/close the quick settings panel |
| `toggleKeybinds` | Open/close the keybind hints overlay |
| `toggleWallpaper` | Open/close the wallpaper picker |

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
| `screenshotFull` | Capture full screen to clipboard |
| `screenshotArea` | Select area with slurp, capture to clipboard |
| `screenshotWindow` | Capture focused window to clipboard |

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
| Bell (capsule) | Toggle notification history | Toggle DND | — | — |
| Settings (capsule) | Toggle quick settings | — | — | — |
| Tray Icon | Activate | Secondary activate | Context menu | — |

## Launcher Keyboard Shortcuts

| Key | Action |
|---|---|
| ← → | Navigate between cards |
| Enter | Activate selected card (launch app, copy clip, connect network, pair device) |
| Tab | Switch to next tab |
| W | Toggle WiFi on/off (WiFi tab, empty search) |
| B | Toggle Bluetooth on/off (BT tab, empty search) |
| Escape | Close launcher |

## Dependencies

- [QuickShell](https://quickshell.outfoxxed.me/) (`qs` binary) with Niri module
- [niri](https://github.com/YaLTeR/niri) compositor
- PipeWire + WirePlumber
- NetworkManager + `nmcli` (for WiFi password connections)
- `brightnessctl` — screen brightness
- `wlsunset` — night light
- `grim` + `slurp` + `wl-copy` — screenshots
- `cliphist` — clipboard history
- JetBrains Mono + Symbols Nerd Font

## Theme

Tokyo Night color palette, centralized in `Config/Theme.qml`. To change the entire shell's appearance, edit the color properties there.

## Architecture

Pure QML — no C++, no build system. QuickShell interprets QML directly. Each subdirectory is a module imported as `qs.<DirName>`.

| Module | Purpose |
|---|---|
| `Config/` | Theme singleton — colors, layout, typography, icons |
| `Core/` | Shared non-visual components — SafeProcess, SafePolledProcess |
| `Bar/` | Status bar — workspaces (Niri IPC), active window, clock, media, network, volume, system tray |
| `Launcher/` | App launcher carousel — apps, clipboard, notifications, WiFi, Bluetooth tabs |
| `Notifications/` | Notification daemon + popup cards with action buttons |
| `NotificationHistory/` | Notification history dropdown |
| `QuickSettings/` | Quick settings panel — brightness, night light, power actions |
| `LockScreen/` | Wayland session lock with PAM auth |
| `Wallpaper/` | Background renderer + carousel picker |
| `KeybindHints/` | Keybind hints overlay |
| `OSD/` | Volume/brightness on-screen display |
| `Widgets/` | Shared UI components — AnimatedPopup, IconButton, PolledProcess |

## License

See [LICENSE](LICENSE).
