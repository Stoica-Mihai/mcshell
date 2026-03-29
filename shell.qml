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

ShellRoot {
    Variants {
        model: Quickshell.screens

        StatusBar {
            required property var modelData
            screen: modelData
            screenName: modelData.name
            onLauncherRequested: appLauncher.toggle()
        }
    }

    NotificationPopup {}
    AppLauncher { id: appLauncher }
    KeybindPanel { id: keybindPanel }

    // IPC — qs -c mcshell ipc call mcshell <function>
    IpcHandler {
        target: "mcshell"

        function toggleLauncher(): void { appLauncher.toggle(); }
        function toggleKeybinds(): void { keybindPanel.toggle(); }
    }
}
