#!/bin/sh
# mcshell screenshot suite — captures key features for README.
# Usage: ./screenshots.sh
# Output: screenshots/ directory with named PNGs
#
# Prerequisites: mcshell must be running (make start)
# Each shot opens a UI element, waits for animation, captures, then closes.

set -e

IPC="quickshell -c mcshell ipc call mcshell"
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

# ── 1. Hero — clean desktop with bar visible ──
echo "[1/10] Hero shot (clean bar)"
shot "01-bar-hero"

# ── 2. Launcher: Apps tab ──
echo "[2/10] Launcher: Apps"
$IPC launcherApps list "" >/dev/null 2>&1
shot "02-launcher-apps"
close_launcher

# ── 3. Launcher: Settings > Theme ──
echo "[3/10] Launcher: Settings > Theme"
$IPC launcherSettings edit theme >/dev/null 2>&1
shot "03-settings-theme"
close_launcher

# ── 4. Launcher: WiFi tab ──
echo "[4/10] Launcher: WiFi"
$IPC launcherWifi list "" >/dev/null 2>&1
shot "04-launcher-wifi"
close_launcher

# ── 5. Calendar popup ──
echo "[5/10] Calendar popup"
$IPC toggleCalendar "" >/dev/null 2>&1
shot "05-calendar"
close_panel toggleCalendar

# ── 6. Weather popup ──
echo "[6/10] Weather popup"
$IPC toggleWeather "" >/dev/null 2>&1
shot "06-weather"
close_panel toggleWeather

# ── 7. Volume panel with per-app sliders ──
echo "[7/10] Volume panel"
$IPC toggleVolume "" >/dev/null 2>&1
shot "07-volume"
close_panel toggleVolume

# ── 8. Notification history ──
echo "[8/10] Notification history"
$IPC toggleNotifications "" >/dev/null 2>&1
shot "08-notifications"
close_panel toggleNotifications

# ── 9. System monitor panel ──
echo "[9/11] System monitor"
$IPC toggleSysInfo "" >/dev/null 2>&1
shot "09-sysinfo"
close_panel toggleSysInfo

# ── 10. Window switcher ──
echo "[10/11] Window switcher"
$IPC toggleWindows >/dev/null 2>&1
shot "09-window-switcher"
$IPC toggleWindows >/dev/null 2>&1
sleep "$CLOSE_DELAY"

# ── 11. Keybind hints ──
echo "[11/11] Keybind hints"
$IPC toggleKeybinds >/dev/null 2>&1
shot "10-keybinds"
$IPC toggleKeybinds >/dev/null 2>&1

echo ""
echo "=== Done: $(ls "$OUT"/*.png 2>/dev/null | wc -l) screenshots ==="
echo "Review: $OUT/"
