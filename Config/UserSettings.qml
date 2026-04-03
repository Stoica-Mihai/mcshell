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
    property alias nightLightMode: adapter.nightLightMode  // "off", "on", "auto"
    property alias nightLightTemp: adapter.nightLightTemp
    property alias nightLightSunrise: adapter.nightLightSunrise
    property alias nightLightSunset: adapter.nightLightSunset
    property alias wallpaperFolder: adapter.wallpaperFolder
    property alias themeName: adapter.themeName

    // Convenience — true when night light is actively applied
    readonly property bool nightLightActive: nightLightMode === "on" || (nightLightMode === "auto" && _autoNightPhase)

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
            property string nightLightMode: "off"
            property int nightLightTemp: 4000
            property string nightLightSunrise: "06:30"
            property string nightLightSunset: "18:30"
            property string wallpaper: ""
            property string wallpaperFolder: ""
            property string themeName: ""
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

    property bool _autoNightPhase: false

    function _restoreNightLight() {
        _applyMode();
    }

    // Called when mode, temp, or auto phase changes
    function _applyMode() {
        if (nightLightMode === "on") {
            _setGammaTemp(root.nightLightTemp);
        } else if (nightLightMode === "auto") {
            _updateAutoPhase();
        } else {
            _setGammaTemp(6500);
        }
    }

    // ── Auto-schedule ──

    function _timeToMinutes(timeStr) {
        const parts = timeStr.split(":").map(Number);
        return parts[0] * 60 + (parts[1] || 0);
    }

    function _isNightNow() {
        const now = new Date();
        const nowMin = now.getHours() * 60 + now.getMinutes();
        const sunset = _timeToMinutes(root.nightLightSunset);
        const sunrise = _timeToMinutes(root.nightLightSunrise);
        // Normal: sunset=18:30, sunrise=06:30 → night is [18:30, 06:30)
        if (sunset > sunrise)
            return nowMin >= sunset || nowMin < sunrise;
        // Inverted: sunset=03:00, sunrise=07:00 → night is [03:00, 07:00)
        return nowMin >= sunset && nowMin < sunrise;
    }

    function _updateAutoPhase() {
        const night = _isNightNow();
        _autoNightPhase = night;
        _setGammaTemp(night ? root.nightLightTemp : 6500);
        // Schedule next check at the boundary
        _scheduleNextCheck();
    }

    function _scheduleNextCheck() {
        const now = new Date();
        const nowMin = now.getHours() * 60 + now.getMinutes();
        const sunset = _timeToMinutes(root.nightLightSunset);
        const sunrise = _timeToMinutes(root.nightLightSunrise);
        const target = _autoNightPhase ? sunrise : sunset;
        let diffMin = target - nowMin;
        if (diffMin <= 0) diffMin += 1440;
        autoTimer.interval = Math.max(diffMin * 60 * 1000 - now.getSeconds() * 1000, 1000);
        autoTimer.restart();
    }

    Timer {
        id: autoTimer
        onTriggered: {
            if (root.nightLightMode === "auto") root._updateAutoPhase();
        }
    }

    onNightLightModeChanged: _applyMode()
    onNightLightTempChanged: { if (nightLightMode !== "off") _applyMode(); }
    onNightLightSunriseChanged: { if (nightLightMode === "auto") _applyMode(); }
    onNightLightSunsetChanged: { if (nightLightMode === "auto") _applyMode(); }

    // ── Dbus interface ──

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
