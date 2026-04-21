#!/bin/sh
# mcshell screenshot suite — captures key features for README.
# Usage: ./screenshots.sh
# Output: screenshots/ directory with named PNGs
#
# Prerequisites: mcshell must be running (make start)
# Each shot opens a UI element, waits for animation, captures, then closes.

set -e

IPC="mcs-qs -c mcshell ipc call mcshell"
OUT="$(cd "$(dirname "$0")" && pwd)/screenshots"
DELAY=1.2    # seconds to wait for animations before capture
CLOSE_DELAY=0.5

mkdir -p "$OUT"

shot() {
    local name="$1"
    sleep "$DELAY"
    niri msg action screenshot-screen
    sleep 0.3
    # Move the latest screenshot to our output dir with a clean name
    latest=$(ls -t ~/Pictures/Screenshots/ | head -1)
    mv ~/Pictures/Screenshots/"$latest" "$OUT/${name}.png"
    echo "  captured: $name"
}

close_launcher() { $IPC toggleLauncher >/dev/null 2>&1; sleep "$CLOSE_DELAY"; }
close_panel() { $IPC "$1" "" >/dev/null 2>&1; sleep "$CLOSE_DELAY"; }

echo "=== mcshell screenshot suite ==="
echo "Output: $OUT/"
echo ""

# Verify shell is running
if ! $IPC toggleDnd >/dev/null 2>&1; then
    echo "ERROR: mcshell is not running. Start it first: make start"
    exit 1
fi
$IPC toggleDnd >/dev/null 2>&1
sleep 0.3

# ── Focus the right screen before starting ──
echo "You have 5 seconds to focus the target screen..."
sleep 5
echo "Starting captures."
echo ""

# ── 1. Hero — clean desktop with bar visible ──
echo "[1/13] Hero shot (clean bar)"
shot "01-bar-hero"

# ── 2. Launcher: Apps tab ──
echo "[2/13] Launcher: Apps"
$IPC launcherApps list >/dev/null 2>&1
shot "02-launcher-apps"
close_launcher

# ── 3. Launcher: Settings > Theme ──
echo "[3/13] Launcher: Settings > Theme"
$IPC launcherSettings edit theme >/dev/null 2>&1
shot "03-settings-theme"
close_launcher

# ── 4. Launcher: WiFi tab ──
echo "[4/13] Launcher: WiFi"
$IPC launcherWifi list >/dev/null 2>&1
shot "04-launcher-wifi"
close_launcher

# ── 5. Launcher: Bluetooth tab ──
echo "[5/13] Launcher: Bluetooth"
$IPC launcherBluetooth list >/dev/null 2>&1
shot "05-launcher-bluetooth"
close_launcher

# ── 6. Calendar popup ──
echo "[6/13] Calendar popup"
$IPC toggleCalendar "" >/dev/null 2>&1
shot "06-calendar"
close_panel toggleCalendar

# ── 6. Weather popup ──
echo "[7/13] Weather popup"
$IPC toggleWeather "" >/dev/null 2>&1
shot "07-weather"
close_panel toggleWeather

# ── 7. Volume panel with per-app sliders ──
echo "[8/13] Volume panel"
$IPC toggleVolume "" >/dev/null 2>&1
shot "08-volume"
close_panel toggleVolume

# ── 8. Notification history ──
echo "[9/13] Notification history"
$IPC toggleNotifications "" >/dev/null 2>&1
shot "09-notifications"
close_panel toggleNotifications

# ── 10. System tray ──
echo "[10/13] System tray — right-click an icon for context menu"
$IPC toggleTray "" >/dev/null 2>&1
sleep 5
shot "10-tray"
close_panel toggleTray

# ── 10. System monitor panel ──
echo "[11/13] System monitor"
$IPC toggleSysInfo "" >/dev/null 2>&1
shot "11-sysinfo"
close_panel toggleSysInfo

# ── 11. Keybind hints ──
echo "[12/13] Keybind hints"
$IPC toggleKeybinds >/dev/null 2>&1
shot "12-keybinds"
$IPC toggleKeybinds >/dev/null 2>&1

# ── 12. Launcher: Wallpaper picker ──
echo "[13/13] Launcher: Wallpaper"
$IPC launcherWallpaper list >/dev/null 2>&1
shot "13-wallpaper-picker"
close_launcher

echo ""
echo "=== Done: $(ls "$OUT"/*.png 2>/dev/null | wc -l) screenshots ==="
echo "Review: $OUT/"
