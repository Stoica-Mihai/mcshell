pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SysInfo
import Qs.NightLight
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
    readonly property int defaultNightTemp: 4000

    property alias nightLightMode: adapter.nightLightMode
    property alias nightLightTemp: adapter.nightLightTemp
    property alias nightLightSunrise: adapter.nightLightSunrise
    property alias nightLightSunset: adapter.nightLightSunset
    property alias wallpaperFolder: adapter.wallpaperFolder
    property alias wallpaperFillMode: adapter.wallpaperFillMode
    property alias wallpaperRotateMode: adapter.wallpaperRotateMode
    property alias wallpaperRotateInterval: adapter.wallpaperRotateInterval
    // Canonical list for both the settings UI (ids + labels) and the rotator
    // (ms). Adding or renaming an interval means editing exactly this array.
    readonly property var wallpaperRotateOptions: [
        { id: "off", label: "Off",      ms: 0 },
        { id: "1m",  label: "1 min",    ms: 60 * 1000 },
        { id: "5m",  label: "5 min",    ms: 5 * 60 * 1000 },
        { id: "15m", label: "15 min",   ms: 15 * 60 * 1000 },
        { id: "30m", label: "30 min",   ms: 30 * 60 * 1000 },
        { id: "1h",  label: "1 hour",   ms: 60 * 60 * 1000 },
        { id: "3h",  label: "3 hours",  ms: 3 * 60 * 60 * 1000 },
        { id: "6h",  label: "6 hours",  ms: 6 * 60 * 60 * 1000 },
        { id: "12h", label: "12 hours", ms: 12 * 60 * 60 * 1000 }
    ]
    readonly property var wallpaperFillModes: [
        { id: "crop",    label: "Crop" },
        { id: "fit",     label: "Fit" },
        { id: "stretch", label: "Stretch" },
        { id: "tile",    label: "Tile" }
    ]
    property alias themeName: adapter.themeName
    property alias idleTimeout: adapter.idleTimeout       // auto-lock timeout in minutes (0 = disabled)
    property alias wallpaperStrategy: adapter.wallpaperStrategy  // strategy name, e.g. "Tonal"
    property alias powerProfile: adapter.powerProfile            // "PowerSaver", "Balanced", "Performance"
    property alias borderAnimation: adapter.borderAnimation      // "midpoint", "clockwise", "corners", "fade"
    property alias barBorderStyle: adapter.barBorderStyle        // "solid", "gradient"
    property alias blurEnabled: adapter.blurEnabled              // bool — surface blur via ext-background-effect
    property alias notifAutoClean: adapter.notifAutoClean        // "never", "30m", "1h", "6h", "24h"
    property alias weatherLocation: adapter.weatherLocation      // display name, e.g. "Bucharest, Romania"
    property alias weatherLat: adapter.weatherLat                // latitude (real)
    property alias weatherLon: adapter.weatherLon                // longitude (real)
    property alias weatherCountryCode: adapter.weatherCountryCode // ISO 3166-1 alpha-2, e.g. "DE"
    property alias clockTimeFormat: adapter.clockTimeFormat      // "24h" or "12h"
    property alias clockShowSeconds: adapter.clockShowSeconds    // bool
    property alias clockDateFormat: adapter.clockDateFormat      // Qt format pattern, e.g. "ddd d MMM yyyy"
    property alias weekStartsOnMonday: adapter.weekStartsOnMonday // bool
    property alias sysInfoEnabled: adapter.sysInfoEnabled        // bool — show waveform + dropdown in bar
    property alias sysInfoInterval: adapter.sysInfoInterval      // ms between polls (1000/2000/5000/10000)
    property alias sysInfoTempUnit: adapter.sysInfoTempUnit      // "C" or "F"
    property alias sysInfoNetUnit: adapter.sysInfoNetUnit        // "bytes" or "bits"
    property alias sysInfoBarMetric: adapter.sysInfoBarMetric    // "cpu", "cpu-history", "memory", "gpu" (gpu falls back to cpu if no GPU)
    property alias sysInfoShowCpu: adapter.sysInfoShowCpu          // bool — per-section dropdown visibility
    property alias sysInfoShowMemory: adapter.sysInfoShowMemory    // bool
    property alias sysInfoShowThermal: adapter.sysInfoShowThermal  // bool
    property alias sysInfoShowGpu: adapter.sysInfoShowGpu          // bool
    property alias sysInfoShowNetwork: adapter.sysInfoShowNetwork  // bool
    property alias sysInfoShowDisk: adapter.sysInfoShowDisk        // bool

    // ── Audio ──
    // Force PipeWire's clock.force-rate to this value on shell start and on
    // change. 0 means "auto" — leave PipeWire to negotiate. PipeWire only
    // honors the value if the device's profile supports it; setting 192000
    // on a card that maxes at 48000 silently falls back to 48000.
    property alias audioForceRate: adapter.audioForceRate

    // ── WiFi launcher card field visibility ──
    property alias wifiCardSignal: adapter.wifiCardSignal
    property alias wifiCardSecurity: adapter.wifiCardSecurity
    property alias wifiCardStatus: adapter.wifiCardStatus
    property alias wifiCardBand: adapter.wifiCardBand
    property alias wifiCardChannel: adapter.wifiCardChannel
    property alias wifiCardBssid: adapter.wifiCardBssid
    property alias wifiCardBitrate: adapter.wifiCardBitrate

    // ── Bluetooth launcher card field visibility ──
    property alias bluetoothCardType: adapter.bluetoothCardType
    property alias bluetoothCardStatus: adapter.bluetoothCardStatus
    property alias bluetoothCardBattery: adapter.bluetoothCardBattery
    property alias bluetoothCardAddress: adapter.bluetoothCardAddress
    property alias bluetoothCardRssi: adapter.bluetoothCardRssi
    property alias bluetoothCardClass: adapter.bluetoothCardClass
    // Hidden GPUs: absence from the list == visible, so new GPUs auto-appear.
    // Stored as JSON-serialized string[] (same pattern as wallpaperPerScreen).
    property alias sysInfoHiddenGpusJson: adapter.sysInfoHiddenGpusJson
    readonly property var sysInfoHiddenGpus: JSON.parse(adapter.sysInfoHiddenGpusJson || "[]")

    function sysInfoGpuVisible(name) {
        return sysInfoHiddenGpus.indexOf(name) < 0;
    }

    function setSysInfoGpuHidden(name, hidden) {
        const cur = sysInfoHiddenGpus.slice();
        const i = cur.indexOf(name);
        if (hidden && i < 0) cur.push(name);
        else if (!hidden && i >= 0) cur.splice(i, 1);
        adapter.sysInfoHiddenGpusJson = JSON.stringify(cur);
    }

    // The "primary" GPU for bar-capsule metrics and preview readouts.
    // Prefers the GPU that's currently driving a connected display output
    // (SysInfo.gpus[i].connectedDisplay, computed in mcs-qs by scanning
    // /sys/class/drm/card*-*/status). Falls through to first-visible
    // then gpus[0] when no GPU reports a connected output.
    function primaryGpu() {
        const gpus = SysInfo.gpus;
        if (gpus.length === 0) return null;

        for (let i = 0; i < gpus.length; i++) {
            if (gpus[i].connectedDisplay) return gpus[i];
        }
        for (let i = 0; i < gpus.length; i++) {
            if (sysInfoGpuVisible(gpus[i].name)) return gpus[i];
        }
        return gpus[0];
    }

    readonly property bool weatherConfigured: adapter.weatherLocation !== ""

    // Composed time format string — single source of truth.
    readonly property string clockTimeFormatString: {
        let fmt = adapter.clockTimeFormat === "12h" ? "h:mm" : "HH:mm";
        if (adapter.clockShowSeconds) fmt += ":ss";
        if (adapter.clockTimeFormat === "12h") fmt += " AP";
        return fmt;
    }
    // Full bar string = date + double space + time.
    readonly property string clockFormatString: adapter.clockDateFormat + "  " + clockTimeFormatString

    // Convenience — true when night light is actively applied
    readonly property bool nightLightActive: nightLightMode === modeManual || (nightLightMode === modeAuto && _autoNightPhase)

    // Full path derived from folder + filename
    readonly property string wallpaperPath: {
        if (adapter.wallpaperFolder === "" || adapter.wallpaper === "") return "";
        return adapter.wallpaperFolder + "/" + adapter.wallpaper;
    }

    // Reactive caches — avoids JSON.parse on every read.
    readonly property var perScreenMap: JSON.parse(adapter.wallpaperPerScreen || "{}")
    // Which screen to rotate: "" = all, or a specific screen name
    property alias wallpaperRotateScreen: adapter.wallpaperRotateScreen

    // Screen names with "All Screens" prefix — shared by wallpaper picker and settings.
    readonly property var screenNames: {
        const names = ["All Screens"];
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            names.push(screens[i].name);
        return names;
    }

    function _splitPath(fullPath) {
        const idx = fullPath.lastIndexOf("/");
        return idx >= 0
            ? { folder: fullPath.substring(0, idx), filename: fullPath.substring(idx + 1) }
            : { folder: "", filename: fullPath };
    }

    function _applyFolder(folder) {
        if (folder && folder !== adapter.wallpaperFolder)
            adapter.wallpaperFolder = folder;
    }

    function setWallpaper(fullPath) {
        const parts = _splitPath(fullPath);
        _applyFolder(parts.folder);
        adapter.wallpaper = parts.filename;
        if (adapter.wallpaperPerScreen !== "{}")
            adapter.wallpaperPerScreen = "{}";
    }

    function setWallpaperForScreen(screenName, fullPath) {
        const parts = _splitPath(fullPath);
        _applyFolder(parts.folder);
        const map = JSON.parse(adapter.wallpaperPerScreen || "{}");
        map[screenName] = parts.filename;
        adapter.wallpaperPerScreen = JSON.stringify(map);
    }

    // Batch version — applies multiple {screenName: fullPath} at once,
    // producing a single adapter write (avoids N parse/stringify cycles).
    function setWallpapersForScreens(assignments) {
        const map = JSON.parse(adapter.wallpaperPerScreen || "{}");
        for (const name in assignments) {
            const parts = _splitPath(assignments[name]);
            _applyFolder(parts.folder);
            map[name] = parts.filename;
        }
        adapter.wallpaperPerScreen = JSON.stringify(map);
    }

    readonly property bool loaded: configFile.loaded
    signal settingsLoaded()

    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/mcshell/settings.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: {
            reload();
            root._applyMode();
        }

        adapter: JsonAdapter {
            id: adapter
            property bool doNotDisturb: false
            property string nightLightMode: "off"
            property int nightLightTemp: root.defaultNightTemp
            property string nightLightSunrise: "06:30"
            property string nightLightSunset: "18:30"
            property string wallpaper: ""
            property string wallpaperFolder: ""
            property string wallpaperPerScreen: "{}"
            property string wallpaperRotateScreen: ""
            property string wallpaperFillMode: "crop"
            property string wallpaperRotateMode: "shuffle"
            property string wallpaperRotateInterval: "off"
            property string themeName: ""
            property int idleTimeout: 0
            property string wallpaperStrategy: "Tonal"
            property string powerProfile: "Balanced"
            property string borderAnimation: "midpoint"
            property string barBorderStyle: "gradient"
            property bool blurEnabled: false
            property string notifAutoClean: "never"
            property string weatherLocation: ""
            property real weatherLat: 0
            property real weatherLon: 0
            property string weatherCountryCode: ""
            property string clockTimeFormat: "24h"
            property bool clockShowSeconds: true
            property string clockDateFormat: "ddd d MMM yyyy"
            property bool weekStartsOnMonday: true
            property bool sysInfoEnabled: true
            property int sysInfoInterval: 2000
            property string sysInfoTempUnit: "C"
            property string sysInfoNetUnit: "bytes"
            property string sysInfoBarMetric: "cpu"
            property bool sysInfoShowCpu: true
            property bool sysInfoShowMemory: true
            property bool sysInfoShowThermal: true
            property bool sysInfoShowGpu: true
            property bool sysInfoShowNetwork: true
            property bool sysInfoShowDisk: false
            property string sysInfoHiddenGpusJson: "[]"
            property int audioForceRate: 0
            property bool wifiCardSignal: true
            property bool wifiCardSecurity: true
            property bool wifiCardStatus: true
            property bool wifiCardBand: true
            property bool wifiCardChannel: false
            property bool wifiCardBssid: false
            property bool wifiCardBitrate: false
            property bool bluetoothCardType: true
            property bool bluetoothCardStatus: true
            property bool bluetoothCardBattery: true
            property bool bluetoothCardAddress: true
            property bool bluetoothCardRssi: false
            property bool bluetoothCardClass: false
        }

        onAdapterUpdated: root._save()

        onLoaded: {
            root._restoreNightLight();
            root._detectDefaultFolder();
            root._save();
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

    // ── Night light (via native gamma control) ──

    property bool _autoNightPhase: false
    property int activeTemp: tempMax  // the currently applied temperature

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
            _setGammaTemp(tempMax);
        }
    }

    // ── Auto-schedule ──

    function _timeToMinutes(timeStr) {
        const parts = timeStr.split(":").map(Number);
        return parts[0] * 60 + (parts[1] || 0);
    }

    // Temperature range and defaults
    readonly property int tempMin: 2500
    readonly property int tempMax: 6500
    readonly property int _autoNightTemp: defaultNightTemp
    readonly property int _transitionMin: 30

    function _updateAutoPhase() {
        const now = new Date();
        const nowMin = now.getHours() * 60 + now.getMinutes();
        const sunset = _timeToMinutes(root.nightLightSunset);
        const sunrise = _timeToMinutes(root.nightLightSunrise);
        const nightTemp = _autoNightTemp;
        const dayTemp = tempMax;
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

    function _setGammaTemp(temp) {
        activeTemp = temp;
        NightLight.temperature = temp;
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
