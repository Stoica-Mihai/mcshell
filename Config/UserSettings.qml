pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core

// Persistent user settings.
// Reads/writes ~/.config/mcshell/settings.json via FileView + JsonAdapter.
// Singleton — import qs.Config and use UserSettings.property directly.
// Adding a new setting: just add a property to the JsonAdapter block.
Singleton {
    id: root

    property alias doNotDisturb: adapter.doNotDisturb
    property alias nightLightActive: adapter.nightLightActive
    property alias wallpaperFolder: adapter.wallpaperFolder
    property alias themeName: adapter.themeName
    property alias nightLightTemp: adapter.nightLightTemp

    // Full path derived from folder + filename
    readonly property string wallpaperPath: {
        if (adapter.wallpaperFolder === "" || adapter.wallpaper === "") return "";
        return adapter.wallpaperFolder + "/" + adapter.wallpaper;
    }

    function setWallpaper(fullPath) {
        const idx = fullPath.lastIndexOf("/");
        if (idx >= 0) {
            adapter.wallpaper = fullPath.substring(idx + 1);
            const folder = fullPath.substring(0, idx);
            if (folder !== adapter.wallpaperFolder)
                adapter.wallpaperFolder = folder;
        } else {
            adapter.wallpaper = fullPath;
        }
    }

    readonly property bool loaded: configFile.loaded

    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/mcshell/settings.json"
        blockLoading: true
        printErrors: false

        adapter: JsonAdapter {
            id: adapter
            property bool doNotDisturb: false
            property bool nightLightActive: false
            property string wallpaper: ""
            property string wallpaperFolder: ""
            property string themeName: ""
            property int nightLightTemp: 4000
        }

        onAdapterUpdated: root._save()

        onLoaded: {
            root._restoreNightLight();
            root._detectDefaultFolder();
        }

        onLoadFailed: error => {
            root._detectDefaultFolder();
        }
    }

    // ── Persistence ──

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: root._performSave()
    }

    function _save() { saveTimer.restart(); }

    function _performSave() { ensureDirProc.running = true; }

    SafeProcess {
        id: ensureDirProc
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.config/mcshell"]
        failMessage: "failed to create config directory"
        onFinished: configFile.writeAdapter()
    }

    // ── Night light (via wl-gammarelay-rs dbus) ──

    Process {
        id: gammaRelay
        command: ["wl-gammarelay-rs", "run"]
        running: true
    }

    function _restoreNightLight() {
        if (nightLightActive) applyNightLight();
    }

    function applyNightLight() {
        _setGammaTemp(root.nightLightTemp);
    }

    function stopNightLight() {
        _setGammaTemp(6500);
    }

    SafeProcess {
        id: gammaSet
        failMessage: ""
    }

    function _setGammaTemp(temp) {
        gammaSet.command = ["busctl", "--user", "set-property", "rs.wl-gammarelay", "/", "rs.wl.gammarelay", "Temperature", "q", String(temp)];
        gammaSet.running = true;
    }

    // ── Wallpaper folder default detection ──

    function _detectDefaultFolder() {
        if (wallpaperFolder === "") defaultFolderProc.running = true;
    }

    SafeProcess {
        id: defaultFolderProc
        command: ["bash", "-c", "if [ -d \"$HOME/Pictures/Wallpapers\" ]; then echo \"$HOME/Pictures/Wallpapers\"; else echo \"$HOME/Pictures\"; fi"]
        failMessage: "failed to detect wallpaper folder"
        onRead: data => {
            const folder = data.trim();
            if (folder !== "" && root.wallpaperFolder === "")
                root.wallpaperFolder = folder;
        }
    }
}
