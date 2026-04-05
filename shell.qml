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

ShellRoot {
    id: shell
    property string _togglePanel: ""
    property int _toggleCounter: 0

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
            onNotifRemoved: nid => notifPopup.removeHistoryById(nid)
            onNotifCleared: notifPopup.clearHistory()
            onNotifPanelOpened: notifPopup.markAllRead()
            panelToggleTrigger: shell._toggleCounter
            panelToggleName: shell._togglePanel
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
        _windowScreenshotPath = "/tmp/mcshell-screenshot-" + Date.now() + ".png";
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
        function launcherApps(): void { appLauncher.openTab("apps"); }
        function launcherClipboard(): void { appLauncher.openTab("clipboard"); }
        function launcherWifi(): void { appLauncher.openTab("wifi"); }
        function launcherBluetooth(): void { appLauncher.openTab("bluetooth"); }
        function launcherWallpaper(): void { appLauncher.openTab("wallpaper"); }
        function launcherSettings(): void { appLauncher.openTab("settings"); }
        function toggleKeybinds(): void { keybindPanel.toggle(); }
        function toggleWindows(): void { windowSwitcher.toggle(); }
        function toggleWallpaper(): void { appLauncher.openTab("wallpaper"); }
        function lock(): void { ShellActions.lock(); }
        function toggleDnd(): void { UserSettings.doNotDisturb = !UserSettings.doNotDisturb; }
        function setWallpaper(path: string): void { ShellActions.setWallpaper(path); }
        function settingsCard(card: string): void { appLauncher.openTab("settings", card); }

        function toggleCalendar(): void { shell._togglePanel = "calendar"; shell._toggleCounter++; }
        function toggleVolume(): void { shell._togglePanel = "volume"; shell._toggleCounter++; }
        function toggleNotifications(): void { shell._togglePanel = "notifications"; shell._toggleCounter++; }
        function toggleSettings(): void { appLauncher.openTab("settings"); }
        function toggleRecording(): void { screenRecording.toggleRecording(); }
        function clipboardList(): string {
            const entries = ClipboardHistory.entries.values;
            const lines = [];
            for (let i = 0; i < entries.length; i++) {
                const e = entries[i];
                lines.push(i + "\t" + e.mimeType + "\t" + e.content.substring(0, 100));
            }
            return lines.join("\n");
        }
        function screenshotFull(): void { shell.screenshotFull(); }
        function screenshotArea(): void { shell.screenshotArea(); }
        function screenshotWindow(): void { shell.screenshotWindow(); }
    }
}
