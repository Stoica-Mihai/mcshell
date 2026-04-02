# mcshell: Community-Ready Improvement Plan

## Context

mcshell is a ~6,500 LoC Wayland desktop shell built on Quickshell. It targets niri and implements: status bar, notifications, app launcher, quick settings, lock screen, wallpaper picker, keybind hints, OSD, and screenshots. The goal is to identify what's missing, broken, or rough — and what quickshell APIs exist but are untapped — to make this a shell worth adopting.

**Reference point:** Noctalia Shell (~130k LoC) is the "full DE" end of the spectrum. mcshell should stay minimal (~10k LoC) but polished and correct.

---

## TIER 1: Reliability & Polish

Fix what exists. Nothing else matters if the shell drains batteries or silently fails.

### ~~1.1 Replace niri CLI Polling with Native APIs~~ ✅
~~Uses `Quickshell.Niri` reactively — `Niri.workspaces`, `Niri.focusedWindow`. No polling.~~

### ~~1.2 Replace Network CLI Polling with Native API~~ ✅
~~`Bar/Network.qml` uses `Quickshell.Networking` reactively. No polling.~~

### ~~1.3 Add Error Handling to All Process Calls~~ ✅
~~All subprocess calls use `Core/SafeProcess.qml` wrapper with built-in error logging via `failMessage` property.~~

### ~~1.4 Enable Notification Actions~~ ✅
~~`actionsSupported: true`, action buttons rendered as pills in `NotificationCard.qml`, calls `ref.actions[i].invoke()`.~~

### ~~1.5 Wire Up OSD Properly~~ ✅
~~Brightness poll reduced to 1000ms.~~

---

## TIER 2: Missing Essentials

Features users expect from any modern desktop shell.

### ~~2.1 Battery / UPower Display~~ ✅
~~`Bar/Battery.qml` + `Bar/CapsuleItem.qml` — icon + %, red below 20%, hidden on desktops without battery.~~

### ~~2.2 WiFi Network Picker~~ ✅
~~`Launcher/CategoryWifi.qml` — full picker with SSID, signal strength, security, password entry, connect/disconnect.~~

### ~~2.3 Bluetooth Device Picker~~ ✅
~~`Launcher/CategoryBluetooth.qml` — full picker with discovery, pairing, connect/disconnect, battery level, device type icons.~~

### 2.4 Settings Persistence
- **Problem:** Only wallpaper path persists. DND, night light, theme choice lost on restart
- **Fix:** Create `Config/UserSettings.qml` singleton managing `~/.config/mcshell/settings.json` (same pattern as `WallpaperConfig.qml`). Use `PersistentProperties` for reload-surviving state
- **Files:** New `Config/UserSettings.qml`, update `NotificationPopup.qml` (DND), `QuickSettingsPanel.qml` (night light)
- **API:** `PersistentProperties`, `FileView`
- **Complexity:** Medium

### 2.5 Multi-Theme Support
- **Problem:** Tokyo Night hardcoded. Single biggest adoption blocker for a cosmetic project
- **Fix:** Make Theme.qml color properties writable, initialized from switchable palette objects. Ship 3-4 built-in palettes: Tokyo Night, Catppuccin Mocha, Gruvbox Dark, Nord. Add theme picker grid in quick settings. Persist via UserSettings
- **Files:** `Config/Theme.qml`, `QuickSettings/QuickSettingsPanel.qml`, `Config/UserSettings.qml`
- **Depends on:** 2.4
- **Complexity:** Medium

---

## TIER 3: Community Differentiators

Features that make people choose mcshell over alternatives.

### 3.1 Polkit Authentication Agent
- **Problem:** Users need a separate polkit agent (lxpolkit, etc). Common pain point on minimal Wayland setups
- **Fix:** Implement themed polkit dialog as layer-shell overlay with password entry. Quickshell has full Polkit API with test implementation at `quickshell/src/services/polkit/test/manual/agent.qml`
- **Files:** New `Polkit/PolkitDialog.qml`, `shell.qml`
- **API:** `Quickshell.Services.Polkit` (PolkitAgent, AuthFlow)
- **Complexity:** Medium

### 3.2 Idle Management
- **Problem:** Lock screen only activates via manual IPC. No auto-lock on idle. Media playback doesn't prevent screen off
- **Fix:** Add `IdleMonitor` (configurable timeout) triggering lock. Add `IdleInhibitor` bound to MPRIS Playing state
- **Files:** `shell.qml`
- **API:** `Quickshell.Wayland.IdleMonitor`, `Quickshell.Wayland.IdleInhibitor`
- **Depends on:** 2.4 (persist timeout setting)
- **Complexity:** Small

### 3.3 Wallpaper-Based Auto-Theming
- **Problem/Opportunity:** Quickshell has `ColorQuantizer` that extracts dominant colors from images. Combined with multi-theme, this enables automatic palette generation from wallpapers
- **Fix:** When wallpaper changes, run ColorQuantizer (depth=3, rescaleSize=64), map extracted colors to theme roles by luminance/saturation sorting
- **Files:** `Config/Theme.qml`, `Wallpaper/WallpaperRenderer.qml`, `QuickSettings/QuickSettingsPanel.qml`
- **API:** `ColorQuantizer` (source, depth, rescaleSize, colors)
- **Depends on:** 2.5
- **Complexity:** Large (color-to-role mapping heuristics)

### 3.4 Compositor Abstraction Layer
- **Problem:** 12 occurrences of "niri" across 5 files. Shell is unusable on Hyprland/Sway
- **Fix:** Create `Compositor/CompositorAdapter.qml` singleton detecting compositor via `$XDG_CURRENT_DESKTOP`. Abstract: `focusWorkspace()`, `logout()`, `screenshotWindow()`. For Hyprland: use `Quickshell.Hyprland` native API (IPC, workspaces, toplevels). For Sway: use `swaymsg`
- **Files:** New `Compositor/CompositorAdapter.qml`, update `Bar/Workspaces.qml`, `QuickSettings/QuickSettingsPanel.qml`, `shell.qml`, `KeybindHints/KeybindPanel.qml`
- **Depends on:** 1.1 (native APIs reduce compositor-specific surface)
- **Complexity:** Large

### 3.5 Extended Launcher Providers
- **Problem:** Only 3 tabs (Apps/Clipboard/Notifications). Modern launchers offer calculator, emoji, window switching
- **Fix:** Add prefix-triggered providers: `=` for calculator (JS eval with sanitization), `>` for window switcher (ToplevelManager.toplevels), `:` for emoji. Or add as additional tabs
- **Files:** `Launcher/AppLauncher.qml` (refactor to support dynamic providers)
- **Depends on:** 1.1 (ToplevelManager for window switcher)
- **Complexity:** Medium per provider

---

## TIER 4: Nice-to-Have

| Item | Description | Complexity |
|------|-------------|------------|
| 4.1 Native Screencopy | Replace grim/slurp with `Quickshell.Wayland.Screencopy` | Small-Medium |
| 4.2 KDL Parser File Watching | Use FileView watch for live config reload | Small |
| 4.3 Accessibility | Add `Accessible.name/role` to all interactive elements, Tab navigation | Large (many files) |
| 4.4 PipeWire Peak Metering | VU meter / pulsing volume icon showing audio activity | Small |
| ~~4.5 Per-App Volume Muting~~ | ✅ `Bar/AppVolume.qml` — per-app volume + mute in capsule dropdown | ~~Small~~ |

---

## Unused Quickshell APIs Summary

| API | Status in mcshell | Opportunity |
|-----|-------------------|-------------|
| ~~`ToplevelManager`~~ | ~~Not used~~ | ~~Done (1.1) — uses Quickshell.Niri~~ |
| ~~`WindowManager`~~ | ~~Not used~~ | ~~Done (1.1)~~ |
| ~~`UPower`~~ | ~~Imported, unused~~ | ~~Done (2.1) — battery in bar capsule~~ |
| ~~`Bluetooth` (full)~~ | ~~Toggle only~~ | ~~Done (2.3) — full device picker~~ |
| ~~`Networking` (full)~~ | ~~SSID only~~ | ~~Done (1.2, 2.2) — reactive + WiFi picker~~ |
| `Polkit` | Not used | Auth agent (3.1) |
| `IdleMonitor/Inhibitor` | Not used | Auto-lock (3.2) |
| `ColorQuantizer` | Not used | Auto-theme (3.3) |
| `Hyprland.*` | Not used | Multi-compositor (3.4) |
| `PersistentProperties` | Not used | Settings persistence (2.4) |
| `FileView` | Used in wallpaper only | General config/state (2.4) |
| `Screencopy` | Not used | Native screenshots (4.1) |
| `PwNode peak metering` | Not used | VU meter (4.4) |
| `Greetd` | Not used | Login greeter (future) |
| ~~`NotificationAction`~~ | ~~Disabled~~ | ~~Done (1.4) — actions enabled~~ |

---

## Sequencing

```
Phase 1 (parallel):  1.1 + 1.2 + 1.3 + 1.4 + 1.5
Phase 2 (parallel):  2.1 + 2.3 + 2.4
Phase 2b:            2.2 (after 1.2) + 2.5 (after 2.4)
Phase 3 (parallel):  3.1 + 3.2 (after 2.4)
Phase 3b:            3.3 (after 2.5) + 3.4 (after 1.1) + 3.5 (after 1.1)
Phase 4:             As time permits
```

**Estimated total:** ~2,000-3,000 new LoC, bringing mcshell to ~9,500 LoC — still firmly minimal.

---

## TIER 5: DRY Refactoring & Component Extraction

Code quality improvements — extract repeated patterns, split oversized files, centralize magic values.

### ~~5.1 Centralize Animation Durations & Magic Colors in Theme~~ ✅
~~Added `animFast/animNormal/animSmooth/animCarousel` + `overlay/overlayHover/backdrop` to Theme. Replaced 56 durations and 15 Qt.rgba calls across 19 files.~~

### ~~5.2 Extract CapsuleItem from StatusBar~~ ✅
~~`Bar/CapsuleItem.qml` — icon + label + hover/alert/underline pattern. Volume and battery use it.~~

### ~~5.3 Make SettingsCard Data-Driven~~ ✅
~~Categories define `{id, icon, source}` objects. SettingsCard loads from source URL — no if/else.~~

### ~~5.4 Split KeybindPanel (627 lines)~~ ✅
~~`KeybindHints/KeybindParser.qml` (262 lines) + `KeybindPanel.qml` (378 lines).~~

### ~~5.5 Extract CalendarPopup from Clock (389 lines)~~ ✅
~~`Bar/CalendarPopup.qml` (329 lines) + `Clock.qml` (69 lines).~~

### ~~5.6 Move Wallpaper Picker into App Launcher as a Category~~ ✅
~~`Launcher/CategoryWallpaper.qml` — reuses carousel, CarouselStrip, LazyModel. Standalone WallpaperPicker removed. Focus border moved to CarouselStrip generic `focused` property.~~

### ~~5.7 Extract SettingsRow Widget~~ ✅
~~`Launcher/SettingsRow.qml` — highlight rect with selected/selectedColor. Used by Audio, Display, Power panels.~~

---

## Verification

For each tier, test by:
1. **Tier 1:** Run `qs -c mcshell`, monitor CPU with `htop` (should see process spawns drop dramatically). Test notification actions from `notify-send -a test --action="reply=Reply" "Test" "Click reply"`. Uninstall `brightnessctl` and verify graceful degradation
2. **Tier 2:** Check battery icon updates on charge/discharge. Connect to new WiFi from picker. Pair BT device. Change theme and restart shell — theme should persist
3. **Tier 3:** Run `pkexec id` and verify polkit dialog appears. Leave shell idle for configured timeout — should lock. Change wallpaper and verify auto-theme generates reasonable colors
4. **General:** Test on both niri and (when 3.4 is done) Hyprland. Verify all IPC commands still work: `qs -c mcshell ipc call mcshell <cmd>`
