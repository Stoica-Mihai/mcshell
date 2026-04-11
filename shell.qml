//@ pragma Env QT_QPA_PLATFORMTHEME=gtk3

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Config
import qs.Bar
import qs.Notifications
import qs.Launcher
import qs.KeybindHints
import qs.LockScreen
import qs.Polkit
import qs.Wallpaper
import qs.Screenshot
import Quickshell.Wayland._DataControl
import qs.WindowSwitcher
import qs.Core
import Quickshell.Bluetooth
import Quickshell.Networking

ShellRoot {
    id: shell
    property string _togglePanel: ""
    property string _toggleMode: ""
    property int _toggleCounter: 0

    // First entry in each list is the default when the caller passes an empty mode.
    // Launcher tabs are not listed here — they declare modes on each LauncherCategory.
    readonly property var _panelModes: ({
        weather:       ["view", "edit"],
        calendar:      ["view"],
        clockSettings: ["view"],
        volume:        ["view"],
        notifications: ["view"],
        media:         ["view"],
        tray:          ["view"]
    })

    // Validate a mode against a panel/tab's supported modes. Returns the
    // resolved mode string (falls back to modes[0] when empty), or null
    // if the kind is unknown or the mode is unsupported — in both cases
    // a console.warn is emitted with the "mcshell IPC:" prefix that
    // test.sh's WARN filter relies on.
    function _resolveMode(kind, name, modes, mode) {
        if (!modes || modes.length === 0) {
            console.warn(`mcshell IPC: unknown ${kind} '${name}'`);
            return null;
        }
        const resolved = mode || modes[0];
        if (modes.indexOf(resolved) < 0) {
            console.warn(`mcshell IPC: ${kind} '${name}' does not support mode '${resolved}' (valid: ${modes.join(", ")})`);
            return null;
        }
        return resolved;
    }

    function _dispatchPanel(name, mode) {
        const resolved = _resolveMode("panel", name, _panelModes[name], mode);
        if (resolved === null) return;
        shell._togglePanel = name;
        shell._toggleMode = resolved;
        shell._toggleCounter++;
    }

    function _dispatchLauncher(tab, mode, target) {
        const resolved = _resolveMode("launcher tab", tab, appLauncher.supportedModesFor(tab), mode);
        if (resolved === null) return;
        appLauncher.openTab(tab, resolved, target);
    }

    // Force singleton initialization so connection watchers start immediately
    Component.onCompleted: NotificationDispatcher
    Variants {
        model: Quickshell.screens

        StatusBar {
            required property var modelData
            screen: modelData
            screenName: modelData.name
            unreadNotifications: notifPopup.unreadCount
            notifHistoryModel: notifPopup.historyModel
            mediaPlaying: shell._mediaPlaying
            isRecording: screenRecording.active
            onLauncherRequested: appLauncher.toggle()
            onWifiRequested: appLauncher.openTab("wifi")
            onBluetoothRequested: appLauncher.openTab("bluetooth")
            onNotifRemoved: nid => notifPopup.removeHistoryById(nid)
            onNotifCleared: notifPopup.clearHistory()
            onNotifPanelOpened: notifPopup.markAllRead()
            panelToggleTrigger: shell._toggleCounter
            panelToggleName: shell._togglePanel
            panelToggleMode: shell._toggleMode
        }
    }

    NotificationPopup { id: notifPopup }
    AppLauncher { id: appLauncher }
    KeybindPanel { id: keybindPanel }
    LockScreen {
        id: lockScreen
        Component.onCompleted: ShellActions.lockScreen = lockScreen
    }
    PolkitDialog {}
    WallpaperRenderer {
        id: wallpaper
        Component.onCompleted: ShellActions.wallpaper = wallpaper
    }
    WallpaperRotator {
        locked: lockScreen.isLocked
    }
    ScreenshotOverlay { id: screenshot }
    WindowSwitcher { id: windowSwitcher }
    Recording { id: screenRecording }

    // ── Idle management ──────────────────────────────────
    // enabled deferred until settings load to avoid timeout=0 race
    IdleMonitor {
        enabled: UserSettings.loaded && UserSettings.idleTimeout > 0
        timeout: Math.max(UserSettings.idleTimeout, 1) * 60
        onIsIdleChanged: if (isIdle && !lockScreen.isLocked) lockScreen.lock()
    }

    // Media inhibitor: true when any MPRIS player is actively playing
    readonly property bool _mediaPlaying: {
        if (!Mpris.players || !Mpris.players.values) return false;
        const all = Mpris.players.values;
        for (let i = 0; i < all.length; i++)
            if (all[i].playbackState === MprisPlaybackState.Playing) return true;
        return false;
    }

    // ── Screenshot functions ────────────────────────────
    function screenshotFull() { screenshot.captureFullScreen(); }
    function screenshotArea() { screenshot.captureArea(); }

    property string _windowScreenshotPath: ""
    function screenshotWindow() {
        _windowScreenshotPath = Theme.screenshotPrefix + Date.now() + ".png";
        _windowScreenshotProc.command = ["niri", "msg", "action", "screenshot-window", "--path", _windowScreenshotPath];
        _windowScreenshotProc.running = true;
    }
    Process {
        id: _windowScreenshotProc
        onExited: (code, status) => {
            if (code === 0) {
                Quickshell.setClipboardImage(shell._windowScreenshotPath);
                NotificationDispatcher.sendWithImage("Screenshot", "Window copied to clipboard", shell._windowScreenshotPath);
            }
        }
    }

    // IPC — qs -c mcshell ipc call mcshell <function>
    IpcHandler {
        target: "mcshell"

        function toggleLauncher(): void { appLauncher.toggle(); }
        function launcherApps(mode: string, target: string): void { shell._dispatchLauncher("apps", mode, target); }
        function launcherClipboard(mode: string, target: string): void { shell._dispatchLauncher("clipboard", mode, target); }
        function launcherWifi(mode: string, target: string): void { shell._dispatchLauncher("wifi", mode, target); }
        function launcherBluetooth(mode: string, target: string): void { shell._dispatchLauncher("bluetooth", mode, target); }
        function launcherWallpaper(mode: string, target: string): void { shell._dispatchLauncher("wallpaper", mode, target); }
        function launcherSettings(mode: string, target: string): void { shell._dispatchLauncher("settings", mode, target); }

        function toggleKeybinds(): void { keybindPanel.toggle(); }
        function toggleWindows(): void { windowSwitcher.toggle(); }
        function lock(): void { ShellActions.lock(); }
        function toggleDnd(): void { UserSettings.doNotDisturb = !UserSettings.doNotDisturb; }
        function setWallpaper(path: string): void { ShellActions.setWallpaper(path); }

        function toggleCalendar(mode: string): void { shell._dispatchPanel("calendar", mode); }
        function toggleVolume(mode: string): void { shell._dispatchPanel("volume", mode); }
        function toggleNotifications(mode: string): void { shell._dispatchPanel("notifications", mode); }
        function toggleWeather(mode: string): void { shell._dispatchPanel("weather", mode); }
        function toggleClockSettings(mode: string): void { shell._dispatchPanel("clockSettings", mode); }
        function toggleRecording(): void { screenRecording.toggleRecording(); }
        function clipboardList(): string {
            const entries = ClipboardHistory.entries.values;
            const lines = [];
            for (let i = 0; i < entries.length; i++) {
                const e = entries[i];
                lines.push(`${i}\t${e.mimeType}\t${e.content.substring(0, 100)}`);
            }
            return lines.join("\n");
        }
        function screenshotFull(): void { shell.screenshotFull(); }
        function screenshotArea(): void { shell.screenshotArea(); }
        function screenshotWindow(): void { shell.screenshotWindow(); }

        function toggleBluetooth(): void { const a = Bluetooth.defaultAdapter; if (a) a.enabled = !a.enabled; }
        function toggleWifi(): void { Networking.wifiEnabled = !Networking.wifiEnabled; }
    }
}
