pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Logind
import Qs.NiriIpc

Singleton {
    id: root

    // Component references — set by shell.qml on startup
    property var lockScreen: null
    property var wallpaper: null

    // Session actions — power actions go through logind on the system bus
    // (org.freedesktop.login1) instead of forking systemctl. polkit gates
    // them the same way; setting interactive=true lets logind prompt.
    function lock() { if (lockScreen) lockScreen.lock(); }
    function logout() { Niri.dispatch(["quit", "--skip-confirmation"]); }
    function reboot() { Logind.reboot(false); }
    function shutdown() { Logind.powerOff(false); }
    function suspend() { Logind.suspend(false); }
    function hibernate() { Logind.hibernate(false); }

    // Wallpaper
    function setWallpaper(path) { if (wallpaper) wallpaper.setWallpaper(path); }
}
