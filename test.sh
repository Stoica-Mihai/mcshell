#!/bin/sh
# mcshell smoke test — starts shell, runs all IPC commands, checks logs.
# Usage: ./test.sh
# Exit code: 0 = pass, 1 = fail

IPC="qs -c mcshell ipc call mcshell"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DELAY=0.5
FAIL_FILE=$(mktemp)
SHELL_LOG=$(mktemp)
echo 0 > "$FAIL_FILE"

fail() { echo "FAIL: $1"; echo 1 > "$FAIL_FILE"; }

ipc_test() {
    result=$($IPC "$1" 2>&1)
    if [ -n "$result" ]; then
        fail "[$1] $result"
    fi
    sleep "$DELAY"
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

qs -c mcshell >"$SHELL_LOG" 2>&1 &
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
ipc_test launcherNotifications; ipc_test toggleLauncher
ipc_test launcherWifi;         ipc_test toggleLauncher
ipc_test launcherBluetooth;    ipc_test toggleLauncher
ipc_test launcherWallpaper;    ipc_test toggleLauncher
ipc_test launcherSettings;     ipc_test toggleLauncher
ipc_test toggleCalendar;       ipc_test toggleCalendar
ipc_test toggleVolume;         ipc_test toggleVolume
ipc_test toggleNotifications;  ipc_test toggleNotifications
ipc_test toggleSettings;       ipc_test toggleLauncher
ipc_test toggleKeybinds;       ipc_test toggleKeybinds
ipc_test toggleDnd;            ipc_test toggleDnd

# ── 3. One-shot commands (skip destructive) ─────────
ipc_test screenshotFull

# ── 4. Stop shell and check logs ────────────────────
echo "Stopping mcshell..."
kill -TERM -"$SHELL_PID" 2>/dev/null || kill -TERM "$SHELL_PID" 2>/dev/null || true
sleep 1
kill -9 -"$SHELL_PID" 2>/dev/null || kill -9 "$SHELL_PID" 2>/dev/null || true
wait "$SHELL_PID" 2>/dev/null || true

ERRORS=$(grep -c "ERROR" "$SHELL_LOG" 2>/dev/null) || ERRORS=0
# Count warnings, excluding the harmless portal registration warning
WARNS=$(grep "WARN" "$SHELL_LOG" 2>/dev/null | grep -cv "qt.qpa.services.*portal" 2>/dev/null) || WARNS=0

echo ""
echo "── Log Results ──"
echo "Errors:   $ERRORS"
echo "Warnings: $WARNS"

if [ "$WARNS" -gt 0 ]; then
    echo ""
    echo "Warnings:"
    grep "WARN" "$SHELL_LOG" | grep -v "qt.qpa.services.*portal" | sort -u
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
