pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Niri
import qs.Core

Singleton {
    id: root

    // Component references — set by shell.qml on startup
    property var lockScreen: null
    property var wallpaper: null

    // Session actions
    function lock() { if (lockScreen) lockScreen.lock(); }
    function logout() { Niri.dispatch(["quit", "--skip-confirmation"]); }
    function reboot() { rebootProc.running = true; }
    function shutdown() { shutdownProc.running = true; }

    // Wallpaper
    function setWallpaper(path) { if (wallpaper) wallpaper.setWallpaper(path); }

    SafeProcess {
        id: rebootProc
        command: ["systemctl", "reboot"]
        failMessage: "reboot failed"
    }
    SafeProcess {
        id: shutdownProc
        command: ["systemctl", "poweroff"]
        failMessage: "shutdown failed"
    }
}
