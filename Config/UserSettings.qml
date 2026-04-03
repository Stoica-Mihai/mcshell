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
    // Night light mode constants
    readonly property string modeOff: "off"
    readonly property string modeManual: "manual"
    readonly property string modeAuto: "auto"

    property alias nightLightMode: adapter.nightLightMode
    property alias nightLightTemp: adapter.nightLightTemp
    property alias nightLightSunrise: adapter.nightLightSunrise
    property alias nightLightSunset: adapter.nightLightSunset
    property alias wallpaperFolder: adapter.wallpaperFolder
    property alias themeName: adapter.themeName

    // Convenience — true when night light is actively applied
    readonly property bool nightLightActive: nightLightMode === modeManual || (nightLightMode === modeAuto && _autoNightPhase)

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
    signal settingsLoaded()

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
            root.settingsLoaded();
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
    property int activeTemp: _autoDayTemp  // the currently applied temperature

    function _restoreNightLight() {
        _applyMode();
    }

    function applyNightLight() { _applyMode(); }

    // Called when mode, temp, or auto phase changes
    function _applyMode() {
        if (nightLightMode === modeManual) {
            _setGammaTemp(root.nightLightTemp);
        } else if (nightLightMode === modeAuto) {
            _updateAutoPhase();
        } else {
            _setGammaTemp(_autoDayTemp);
        }
    }

    // ── Auto-schedule ──

    function _timeToMinutes(timeStr) {
        const parts = timeStr.split(":").map(Number);
        return parts[0] * 60 + (parts[1] || 0);
    }

    // Auto mode uses fixed endpoints — independent of manual temperature
    readonly property int _autoDayTemp: 6500
    readonly property int _autoNightTemp: 4000
    readonly property int _transitionMin: 30

    function _updateAutoPhase() {
        const now = new Date();
        const nowMin = now.getHours() * 60 + now.getMinutes();
        const sunset = _timeToMinutes(root.nightLightSunset);
        const sunrise = _timeToMinutes(root.nightLightSunrise);
        const nightTemp = _autoNightTemp;
        const dayTemp = _autoDayTemp;
        const trans = _transitionMin;

        // Calculate how "night" we are (0.0 = full day, 1.0 = full night)
        const factor = _nightFactor(nowMin, sunset, sunrise, trans);
        _autoNightPhase = factor > 0;

        const temp = Math.round(dayTemp + (nightTemp - dayTemp) * factor);
        _setGammaTemp(temp);

        // Re-check every minute during transitions, less often otherwise
        autoTimer.interval = (factor > 0 && factor < 1) ? 60000 : 300000;
        autoTimer.restart();
    }

    // Returns 0.0 (full day) to 1.0 (full night) with smooth ramp
    function _nightFactor(nowMin, sunset, sunrise, trans) {
        // Normalize to handle wrap-around (sunset > sunrise means night crosses midnight)
        function dist(a, b) {
            let d = a - b;
            if (d > 720) d -= 1440;
            if (d < -720) d += 1440;
            return d;
        }

        const afterSunset = dist(nowMin, sunset);
        const beforeSunrise = dist(sunrise, nowMin);

        // Ramping into night (around sunset)
        if (afterSunset >= 0 && afterSunset <= trans)
            return afterSunset / trans;

        // Ramping into day (around sunrise)
        if (beforeSunrise >= 0 && beforeSunrise <= trans)
            return beforeSunrise / trans;

        // Full night: past sunset+trans and before sunrise-trans
        const pastSunsetRamp = afterSunset > trans;
        const beforeSunriseRamp = beforeSunrise > trans;
        if (pastSunsetRamp && beforeSunriseRamp)
            return 1.0;

        // Full day
        return 0.0;
    }

    Timer {
        id: autoTimer
        onTriggered: {
            if (root.nightLightMode === root.modeAuto) root._updateAutoPhase();
        }
    }

    // ── Dbus interface ──

    Process {
        id: gammaSet
    }

    function _setGammaTemp(temp) {
        activeTemp = temp;
        gammaSet.command = ["busctl", "--user", "set-property", "rs.wl-gammarelay", "/", "rs.wl.gammarelay", "Temperature", "q", String(temp)];
        gammaSet.running = false;
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
