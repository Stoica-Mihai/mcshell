#!/bin/sh
# mcshell smoke test — starts shell, runs all IPC commands, checks logs.
# Usage: ./test.sh
# Exit code: 0 = pass, 1 = fail

IPC="mcs-qs -c mcshell ipc call mcshell"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DELAY=0.5
FAIL_FILE=$(mktemp)
SHELL_LOG=$(mktemp)
echo 0 > "$FAIL_FILE"

fail() { echo "FAIL: $1"; echo 1 > "$FAIL_FILE"; }

ipc_test() {
    result=$($IPC "$@" 2>&1)
    if [ -n "$result" ]; then
        fail "[$*] $result"
    fi
    sleep "$DELAY"
}

# Assert that an IPC call produces a specific warning in the log.
# Captures a line marker before the call so earlier log entries can't
# masquerade as the expected warning. "mcshell IPC:" warnings are filtered
# out of the final WARN count at the bottom of this script.
# $1 = IPC args (space-separated), $2 = substring that must appear in new log lines
expect_warn() {
    before=$(wc -l < "$SHELL_LOG")
    $IPC $1 >/dev/null 2>&1
    sleep "$DELAY"
    if ! tail -n +$((before + 1)) "$SHELL_LOG" | grep -q "$2"; then
        fail "expected warn missing for [$1]: $2"
    fi
}

# ── 1. Start shell ──────────────────────────────────
echo "Starting mcshell..."

# Ensure symlink exists
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
LINK="$CONFIG_DIR/mcshell"
if [ ! -e "$LINK" ]; then
    mkdir -p "$CONFIG_DIR"
    ln -s "$SCRIPT_DIR" "$LINK"
fi

mcs-qs -c mcshell >"$SHELL_LOG" 2>&1 &
SHELL_PID=$!
sleep 4

# Verify it's running
if ! $IPC toggleDnd >/dev/null 2>&1; then
    fail "Shell did not start"
    rm -f "$FAIL_FILE"
    exit 1
fi
$IPC toggleDnd >/dev/null 2>&1
sleep "$DELAY"

echo "Shell running. Testing IPC commands..."

# ── 2. Toggle commands (open then close) ────────────
ipc_test toggleLauncher;       ipc_test toggleLauncher
ipc_test launcherApps;         ipc_test toggleLauncher
ipc_test launcherClipboard;    ipc_test toggleLauncher
ipc_test launcherWifi;         ipc_test toggleLauncher
ipc_test launcherBluetooth;    ipc_test toggleLauncher
ipc_test launcherWallpaper;    ipc_test toggleLauncher
ipc_test launcherSettings;     ipc_test toggleLauncher

# New mode variants (valid)
ipc_test launcherApps list;       ipc_test toggleLauncher
ipc_test launcherSettings list;   ipc_test toggleLauncher

# Settings card pre-selection via `target` arg — one card × three modes covers
# the full mode × target matrix. The dispatcher is target-agnostic, so testing
# every card id would just duplicate coverage of the same code path.
ipc_test launcherSettings view power;    ipc_test toggleLauncher
ipc_test launcherSettings list power;    ipc_test toggleLauncher
ipc_test launcherSettings edit power;    ipc_test toggleLauncher
# edit with no target — lands on first card (selectedIndex 0)
ipc_test launcherSettings edit;          ipc_test toggleLauncher

# Bar panel toggles
ipc_test toggleCalendar;       ipc_test toggleCalendar
ipc_test toggleVolume;         ipc_test toggleVolume
ipc_test toggleNotifications;  ipc_test toggleNotifications
ipc_test toggleWeather;        ipc_test toggleWeather
ipc_test toggleWeather view;   ipc_test toggleWeather
ipc_test toggleWeather edit;   ipc_test toggleWeather
ipc_test toggleClockSettings;  ipc_test toggleClockSettings
ipc_test toggleKeybinds;       ipc_test toggleKeybinds
ipc_test toggleWindows;        ipc_test toggleWindows
ipc_test toggleDnd;            ipc_test toggleDnd
ipc_test toggleWifi;           ipc_test toggleWifi
ipc_test toggleBluetooth;      ipc_test toggleBluetooth
# clipboardList returns a string on stdout — fire-and-forget, not via ipc_test
$IPC clipboardList >/dev/null 2>&1; sleep "$DELAY"

# ── 2b. Validation warnings (must fire) ─────────────
# These calls MUST each produce a specific console.warn. The suite fails
# if the expected warning is absent. All "mcshell IPC:" warnings are filtered
# out of the aggregate WARN count at the bottom.
echo "Testing validation warnings..."
expect_warn "toggleVolume edit"         "panel 'volume' does not support mode 'edit'"
expect_warn "launcherApps edit"         "launcher tab 'apps' does not support mode 'edit'"
expect_warn "toggleCalendar edit"       "panel 'calendar' does not support mode 'edit'"

# ── 3. One-shot commands (skip destructive) ─────────
ipc_test screenshotFull

# ── 4. Stop shell and check logs ────────────────────
echo "Stopping mcshell..."
kill -TERM -"$SHELL_PID" 2>/dev/null || kill -TERM "$SHELL_PID" 2>/dev/null || true
sleep 1
kill -9 -"$SHELL_PID" 2>/dev/null || kill -9 "$SHELL_PID" 2>/dev/null || true
wait "$SHELL_PID" 2>/dev/null || true

ERRORS=$(grep -c "ERROR" "$SHELL_LOG" 2>/dev/null) || ERRORS=0
# Count warnings, excluding:
#   - harmless portal registration warning
#   - intentional "mcshell IPC:" warnings asserted via expect_warn
#   - benign Qt "Could not load icon" from desktop entries whose Icon field
#     is a raw font glyph — environment-dependent, not a shell bug
WARNS=$(grep "WARN" "$SHELL_LOG" 2>/dev/null \
    | grep -v "qt.qpa.services.*portal" \
    | grep -v "mcshell IPC:" \
    | grep -cv "Could not load icon" 2>/dev/null) || WARNS=0

echo ""
echo "── Log Results ──"
echo "Errors:   $ERRORS"
echo "Warnings: $WARNS"

if [ "$WARNS" -gt 0 ]; then
    echo ""
    echo "Warnings:"
    grep "WARN" "$SHELL_LOG" \
        | grep -v "qt.qpa.services.*portal" \
        | grep -v "mcshell IPC:" \
        | grep -v "Could not load icon" \
        | sort -u
    echo 1 > "$FAIL_FILE"
fi

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "Errors:"
    grep "ERROR" "$SHELL_LOG" | sort -u
    echo 1 > "$FAIL_FILE"
fi

rm -f "$SHELL_LOG"

# ── 5. Verdict ──────────────────────────────────────
echo ""
RESULT=$(cat "$FAIL_FILE")
rm -f "$FAIL_FILE"

if [ "$RESULT" = "0" ]; then
    echo "VERDICT: PASS"
    exit 0
else
    echo "VERDICT: FAIL"
    exit 1
fi
