pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Niri

// Reactive "which niri output currently has focus?" — exposes the focused
// workspace's output name and the matching Quickshell.screens entry.
//
// Sourced entirely from Niri.workspaces. The previous `niri msg -j
// focused-output` Process bootstrap is gone — the IPC stream populates
// workspaces almost immediately on connection, and the only worst-case
// would be a screenshot keyed within the first frame after shell start
// going to screens[0] instead of the focused monitor.
Singleton {
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
