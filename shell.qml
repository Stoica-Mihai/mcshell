//@ pragma Env QT_QPA_PLATFORMTHEME=gtk3

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Config
import qs.Bar
import qs.Notifications
import qs.Launcher
import qs.QuickSettings
import qs.KeybindHints
import qs.LockScreen
import qs.Wallpaper

ShellRoot {
    id: shell
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
        }
    }

    NotificationPopup { id: notifPopup }
    AppLauncher {
        id: appLauncher
        notifHistoryModel: notifPopup.historyModel
        onNotificationsViewed: notifPopup.markAllRead()
    }
    KeybindPanel { id: keybindPanel }
    LockScreen { id: lockScreen }
    WallpaperRenderer { id: wallpaper }
    WallpaperPicker {
        id: wallpaperPicker
        onWallpaperSelected: path => wallpaper.setWallpaper(path)
    }

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
        function toggleKeybinds(): void { keybindPanel.toggle(); }
        function toggleWallpaper(): void { wallpaperPicker.toggle(); }
        function lock(): void { lockScreen.lock(); }
        function toggleDnd(): void { notifPopup.doNotDisturb = !notifPopup.doNotDisturb; }
        function setWallpaper(path: string): void { wallpaper.setWallpaper(path); }

        function screenshotFull(): void { shell.screenshotFull(); }
        function screenshotArea(): void { shell.screenshotArea(); }
        function screenshotWindow(): void { shell.screenshotWindow(); }
    }
}
