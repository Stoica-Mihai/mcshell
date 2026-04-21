pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Niri

// Reactive "which niri output currently has focus?" — exposes the focused
// workspace's output name and the matching Quickshell.screens entry.
//
// Replaces five near-identical `Process { command: ["niri", "msg", "-j",
// "focused-output"] }` + StdioCollector + JSON.parse blocks scattered
// across the launcher, window switcher, keybind panel, screenshot
// overlay, wallpaper category, and recording driver. Niri's IPC already
// pushes focus changes into NiriWorkspace.focused, so the shell-out was
// never necessary — just underutilised native state.
//
// Usage:
//   import qs.Core
//   const name = FocusedOutput.name;      // "DP-4" or "" if none
//   const s    = FocusedOutput.screen;    // matching Quickshell screen
//                                         // object, or null if none
//
// Read at the moment you need it (e.g. before reassigning a layer-shell
// surface's screen). Binding a layer-shell surface's screen reactively
// would race with Qt 6.11's handleScreensChanged — see the Screenshot
// dispatcher note in CLAUDE.md.
QtObject {
    id: root

    readonly property string name: {
        const workspaces = Niri.workspaces ? Niri.workspaces.values : [];
        for (let i = 0; i < workspaces.length; i++) {
            if (workspaces[i].focused) return workspaces[i].output;
        }
        return "";
    }

    readonly property var screen: {
        if (!name) return null;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name) return screens[i];
        }
        return null;
    }
}
