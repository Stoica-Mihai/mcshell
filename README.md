# mcshell

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
Horizontal filmstrip carousel with smooth sliding animation. Two-level keyboard navigation: Left/Right to switch categories (Level 1), Enter to dive in, Left/Right to navigate cards (Level 2), Escape to go back. Seven tabs:
- **Apps** — fuzzy search, large icon + name + description in expanded view
- **Clipboard** — cliphist integration, lazy-loaded, image entry detection with metadata display
- **Notifications** — browse past notifications with search
- **WiFi** — scan and connect to networks, inline password input, signal strength and security display. Ctrl+W to toggle WiFi
- **Bluetooth** — discover, pair, and connect devices with battery display. Ctrl+B to toggle Bluetooth
- **Wallpaper** — browse and apply wallpapers from configured folder, lazy-loaded thumbnails, active wallpaper highlighted
- **Settings** — audio (device selection, volume), display (brightness, night light), power (lock/logout/reboot/shutdown)

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
| `Core/` | Shared non-visual components — SafeProcess, SafePolledProcess, LazyModel |
| `Bar/` | Status bar — workspaces (Niri IPC), active window, clock + calendar, media, network, volume, battery, system tray |
| `Launcher/` | App launcher carousel — apps, clipboard, notifications, WiFi, Bluetooth, wallpaper, settings tabs |
| `Notifications/` | Notification daemon + popup cards with action buttons |
| `NotificationHistory/` | Notification history dropdown |
| `QuickSettings/` | Quick settings panel — brightness, night light, power actions |
| `LockScreen/` | Wayland session lock with PAM auth |
| `Wallpaper/` | Background renderer + config persistence |
| `KeybindHints/` | Keybind parser + hints overlay |
| `OSD/` | Volume/brightness on-screen display |
| `Widgets/` | Shared UI components — AnimatedPopup, IconButton, SliderTrack, ControlSlider |

## License

See [LICENSE](LICENSE).
