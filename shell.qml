//@ pragma Env QT_QPA_PLATFORMTHEME=gtk3

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Config
import qs.Bar
import qs.Notifications
import qs.Launcher
import qs.KeybindHints
import qs.LockScreen
import qs.Wallpaper

ShellRoot {
    id: shell
    property string _togglePanel: ""
    property int _toggleCounter: 0
    Variants {
        model: Quickshell.screens

        StatusBar {
            required property var modelData
            screen: modelData
            screenName: modelData.name
            unreadNotifications: notifPopup.unreadCount
            doNotDisturb: notifPopup.doNotDisturb
            notifHistoryModel: notifPopup.historyModel
            onLauncherRequested: appLauncher.toggle()
            onNotifRemoved: nid => notifPopup.removeHistoryById(nid)
            onNotifCleared: notifPopup.clearHistory()
            onNotifPanelOpened: notifPopup.markAllRead()
            onDndToggled: notifPopup.doNotDisturb = !notifPopup.doNotDisturb
            panelToggleTrigger: shell._toggleCounter
            panelToggleName: shell._togglePanel
        }
    }

    NotificationPopup { id: notifPopup }
    AppLauncher {
        id: appLauncher
        notifHistoryModel: notifPopup.historyModel
        onNotificationsViewed: notifPopup.markAllRead()
        onWallpaperSelected: path => wallpaper.setWallpaper(path)
    }
    KeybindPanel { id: keybindPanel }
    LockScreen { id: lockScreen }
    WallpaperRenderer { id: wallpaper }

    // ── Screenshot functions ────────────────────────────
    function screenshotFull() {
        Quickshell.execDetached({ command: ["sh", "-c",
            "f=/tmp/mcshell-screenshot-$$.png && grim \"$f\" && wl-copy < \"$f\" && notify-send -t 5000 -h string:image-path:\"$f\" 'Screenshot' 'Full screen copied to clipboard'"
        ] });
    }

    function screenshotArea() {
        Quickshell.execDetached({ command: ["sh", "-c",
            "f=/tmp/mcshell-screenshot-$$.png && grim -g \"$(slurp)\" \"$f\" && wl-copy < \"$f\" && notify-send -t 5000 -h string:image-path:\"$f\" 'Screenshot' 'Area copied to clipboard'"
        ] });
    }

    function screenshotWindow() {
        Quickshell.execDetached({ command: ["sh", "-c",
            "f=/tmp/mcshell-screenshot-$$.png && niri msg action screenshot-window --path \"$f\" && wl-copy < \"$f\" && notify-send -t 5000 -h string:image-path:\"$f\" 'Screenshot' 'Window copied to clipboard'"
        ] });
    }

    // IPC — qs -c mcshell ipc call mcshell <function>
    IpcHandler {
        target: "mcshell"

        function toggleLauncher(): void { appLauncher.toggle(); }
        function launcherApps(): void { appLauncher.openTab(0); }
        function launcherClipboard(): void { appLauncher.openTab(1); }
        function launcherNotifications(): void { appLauncher.openTab(2); }
        function launcherWifi(): void { appLauncher.openTab(3); }
        function launcherBluetooth(): void { appLauncher.openTab(4); }
        function launcherWallpaper(): void { appLauncher.openTab(5); }
        function launcherSettings(): void { appLauncher.openTab(6); }
        function toggleKeybinds(): void { keybindPanel.toggle(); }
        function toggleWallpaper(): void { appLauncher.openTab(5); }
        function lock(): void { lockScreen.lock(); }
        function toggleDnd(): void { notifPopup.doNotDisturb = !notifPopup.doNotDisturb; }
        function setWallpaper(path: string): void { wallpaper.setWallpaper(path); }

        function toggleCalendar(): void { shell._togglePanel = "calendar"; shell._toggleCounter++; }
        function toggleVolume(): void { shell._togglePanel = "volume"; shell._toggleCounter++; }
        function toggleNotifications(): void { shell._togglePanel = "notifications"; shell._toggleCounter++; }
        function toggleSettings(): void { appLauncher.openTab(6); }
        function screenshotFull(): void { shell.screenshotFull(); }
        function screenshotArea(): void { shell.screenshotArea(); }
        function screenshotWindow(): void { shell.screenshotWindow(); }
    }
}
