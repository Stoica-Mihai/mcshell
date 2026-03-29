# mcshell

A custom Wayland desktop shell built with [QuickShell](https://quickshell.org/) for the [niri](https://github.com/YaLTeR/niri) compositor. Pure QML, no build step.

## Features

### Status Bar
- **Workspaces** — animated pills, click to switch, scroll to cycle
- **Active Window** — title display, click to focus
- **Clock** — date + time, click for calendar with month/year picker
- **Media** — MPRIS controls (prev/play/next), click track title for expanded player with album art, seek bar, live stream detection
- **Volume** — PipeWire native, scroll to adjust, middle-click mute, left-click for volume panel with per-app sliders
- **System Tray** — colorized icons, right-click context menus, hover tooltips
- **Notifications** — bell icon with unread badge, left-click for history dropdown, middle-click for Do Not Disturb
- **Quick Settings** — power menu (lock/logout/reboot/shutdown), brightness slider, wifi, bluetooth, night light toggles

### App Launcher
Horizontal filmstrip carousel with smooth sliding animation. Three tabs:
- **Apps** — fuzzy search, large icon + name + description in expanded view
- **Clipboard** — cliphist integration, image entry detection with metadata display
- **Notifications** — browse past notifications with search

### Notifications
- Popup cards with circular donut countdown timer
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

### Launcher & Panels

| Command | Description |
|---|---|
| `toggleLauncher` | Open/close the app launcher carousel |
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
| Volume | Toggle volume panel | Toggle mute | — | Adjust volume |
| Tray Icon | Activate | Secondary activate | Context menu | — |
| Bell | Notification history | Toggle DND | — | — |
| Cogwheel | Toggle quick settings | — | — | — |

## Dependencies

- [QuickShell](https://quickshell.org/) (`qs` binary)
- [niri](https://github.com/YaLTeR/niri) compositor
- PipeWire + WirePlumber
- NetworkManager
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
| `Bar/` | Status bar with all widgets |
| `Launcher/` | App launcher carousel with clipboard + notification tabs |
| `Notifications/` | Notification daemon + popup cards |
| `NotificationHistory/` | Notification history dropdown |
| `QuickSettings/` | Quick settings panel with toggles |
| `LockScreen/` | Wayland session lock with PAM auth |
| `Wallpaper/` | Background renderer + carousel picker |
| `KeybindHints/` | Keybind hints overlay |
| `OSD/` | Volume/brightness on-screen display (disabled) |
| `Widgets/` | Shared components (AnimatedPopup, IconButton, SliderTrack, etc.) |

## License

See [LICENSE](LICENSE).
