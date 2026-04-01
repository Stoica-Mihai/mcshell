# Testing mcshell

## When to test

Run this checklist before committing any change that touches:
- `AppLauncher.qml` or any `Category*.qml` or `LauncherCategory.qml`
- `CarouselStrip.qml`, `DisabledCard.qml`, `SettingsCard.qml`
- `StatusBar.qml` or bar panel components
- `shell.qml` (IPC handlers)
- Any component imported by the above

## How to run (fully automated, no user interaction needed)

### Start the shell
```sh
# Kill any existing instance
pkill -f "qs.*mcshell" 2>/dev/null
sleep 1

# Start fresh
./start.sh &
sleep 3
```

### Run smoke test
```sh
FAILED=0
for cmd in toggleLauncher launcherApps launcherClipboard launcherNotifications launcherWifi launcherBluetooth launcherSettings toggleLauncher toggleCalendar toggleCalendar toggleVolume toggleVolume toggleNotifications toggleNotifications toggleSettings toggleDnd toggleDnd; do
    result=$(qs -c mcshell ipc call mcshell "$cmd" 2>&1)
    if [ -n "$result" ]; then
        echo "FAIL [$cmd]: $result"
        FAILED=1
    fi
    sleep 0.5
done

if [ "$FAILED" = "0" ]; then
    echo "PASS: All IPC commands executed successfully"
else
    echo "FAIL: Some IPC commands failed"
fi
```

### Check for warnings in the log
```sh
LOG=$(ls -t /run/user/$(id -u)/quickshell/by-id/*/log.qslog 2>/dev/null | head -1)
if [ -n "$LOG" ]; then
    # Check for QML errors and warnings
    ERRORS=$(grep -c "ERROR" "$LOG" 2>/dev/null || echo 0)
    WARNS=$(grep -c "WARN.*scene:" "$LOG" 2>/dev/null || echo 0)
    echo "Errors: $ERRORS, Scene warnings: $WARNS"
    if [ "$ERRORS" -gt 0 ]; then grep "ERROR" "$LOG"; fi
    if [ "$WARNS" -gt 0 ]; then grep "WARN.*scene:" "$LOG" | sort -u; fi
else
    echo "No log file found"
fi
```

## One-liner for CI / pre-commit

```sh
pkill -f "qs.*mcshell" 2>/dev/null; sleep 1; ./start.sh & sleep 3; PASS=true; for cmd in toggleLauncher launcherApps launcherClipboard launcherNotifications launcherWifi launcherBluetooth launcherSettings toggleLauncher toggleCalendar toggleCalendar toggleVolume toggleVolume toggleNotifications toggleNotifications toggleSettings toggleDnd toggleDnd; do r=$(qs -c mcshell ipc call mcshell "$cmd" 2>&1); [ -n "$r" ] && echo "FAIL: $cmd" && PASS=false; sleep 0.5; done; $PASS && echo "ALL PASS" || echo "SOME FAILED"
```

## Full end-to-end test (copy-paste ready)

```sh
# 1. Start shell
./start.sh 2>/dev/null &
disown
sleep 4

# 2. IPC smoke test
FAILED=0
for cmd in toggleLauncher launcherApps launcherClipboard launcherNotifications launcherWifi launcherBluetooth launcherSettings toggleLauncher toggleCalendar toggleCalendar toggleVolume toggleVolume toggleNotifications toggleNotifications toggleSettings toggleDnd toggleDnd; do
    result=$(qs -c mcshell ipc call mcshell "$cmd" 2>&1)
    if [ -n "$result" ]; then echo "FAIL [$cmd]"; FAILED=1; fi
    sleep 0.5
done
[ "$FAILED" = "0" ] && echo "IPC: ALL PASS" || echo "IPC: SOME FAILED"

# 3. Log check
LOG=$(ls -t /run/user/$(id -u)/quickshell/by-id/*/log.qslog 2>/dev/null | head -1)
ERRORS=$(grep -c "ERROR" "$LOG" 2>/dev/null || echo 0)
WARNS=$(grep -c "WARN.*scene:" "$LOG" 2>/dev/null || echo 0)
echo "Log: Errors=$ERRORS, Warnings=$WARNS"
[ "$WARNS" -gt 0 ] && grep "WARN.*scene:" "$LOG" | sort -u
[ "$ERRORS" -gt 0 ] && grep "ERROR" "$LOG"

# 4. Verdict
[ "$FAILED" = "0" ] && [ "$ERRORS" = "0" ] && [ "$WARNS" = "0" ] && echo "VERDICT: PASS" || echo "VERDICT: FAIL"
```

NOTE: The shell must be running on a Wayland session with niri. If the shell is already running,
skip step 1 — the IPC commands will reach the existing instance.

## What constitutes a pass

- Zero `ERROR` lines in log
- Zero `WARN scene:` lines in log (QML binding errors)
- All IPC commands execute without output (no "No running instances" errors)
- Shell remains responsive after test sequence (doesn't crash)

## What to investigate but not block on

- `WARN qt.qpa.services` — portal registration, harmless
- `WARN quickshell.service.notifications` — notification server already registered, harmless
- `[mcshell]` prefixed warnings — SafeProcess failures, may be expected if optional tools not installed
