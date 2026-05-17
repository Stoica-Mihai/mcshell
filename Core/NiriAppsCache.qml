pragma Singleton

import QtQuick
import Quickshell
import Qs.NiriIpc

// Shell-level cache of "which unique appIds live on which workspace?"
//
// Previously every StatusBar's Workspaces instance walked Niri.windows.values
// in its own _appsPerWorkspace binding — with N screens that's N full window
// scans per Niri window event. Centralising the walk here means it runs once
// per event regardless of screen count; each StatusBar reads the shared map.
//
// The binding tracks Niri.windows.values, so it re-evaluates whenever the
// window list mutates (add/remove/property change that the model surfaces
// through values). No per-window Connections needed — the IPC model already
// churns on the events we care about (workspace move, appId change).
Singleton {
    id: root

    // workspaceId -> [appId, appId, ...] (unique, preserves first-seen order)
    readonly property var appsByWorkspace: {
        const windows = Niri.windows ? Niri.windows.values : [];
        const map = {};
        for (let i = 0; i < windows.length; i++) {
            const w = windows[i];
            const wsId = w.workspaceId;
            if (wsId < 0) continue;
            if (!map[wsId]) map[wsId] = [];
            if (map[wsId].indexOf(w.appId) < 0)
                map[wsId].push(w.appId);
        }
        return map;
    }
}
