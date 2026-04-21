import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Core
import qs.Widgets

// Display settings card content — brightness + night light.
SettingsPanel {
    id: root

    // ── Header ──
    readonly property string headerIcon: Theme.iconBrightness
    readonly property string headerTitle: "Display"
    readonly property string panelLegend: Theme.legend(Theme.hintUpDown, Theme.hintAdjust, Theme.hintEnter + " select", Theme.hintBack)
    readonly property string headerSubtitle: {
        const bri = `${Brightness.percent}%`;
        const parts = [];
        if (UserSettings.nightLightMode === UserSettings.modeManual) parts.push("Night light manual");
        else if (UserSettings.nightLightMode === UserSettings.modeAuto) parts.push("Night light auto");
        if (UserSettings.idleTimeout > 0) parts.push(`Lock ${UserSettings.idleTimeout}m`);
        if (UserSettings.notifAutoClean !== "never") parts.push(`Clean ${UserSettings.notifAutoClean}`);
        return parts.length > 0 ? `${bri}${Theme.separator}${parts.join(Theme.separator)}` : bri;
    }
    readonly property color headerColor: Theme.yellow

    // ── Night light mode mapping ──
    readonly property var modes: [UserSettings.modeOff, UserSettings.modeManual, UserSettings.modeAuto]
    readonly property int modeIndex: modes.indexOf(UserSettings.nightLightMode)
    readonly property bool nightOn: UserSettings.nightLightMode !== UserSettings.modeOff
    readonly property bool nightAuto: UserSettings.nightLightMode === UserSettings.modeAuto
    readonly property bool nightManual: UserSettings.nightLightMode === UserSettings.modeManual

    // ── Notification auto-clean mapping ──
    readonly property var _cleanValues: ["never", "30m", "1h", "6h", "24h"]
    readonly property var _cleanLabels: ["Never", "30 min", "1 hour", "6 hours", "24 hours"]
    readonly property int _cleanIndex: Math.max(0, _cleanValues.indexOf(UserSettings.notifAutoClean))

    // Declarative item registry — each row's `selected` binding and the
    // panel's adjustLeft/adjustRight dispatch resolve by id, so visibility
    // changes (night light off/auto/manual) rearrange indices automatically.
    readonly property var items: {
        const list = [
            { id: "brightness",
              adjustLeft:  () => Brightness.set(Math.max(0, Brightness.percent - 5)),
              adjustRight: () => Brightness.set(Math.min(100, Brightness.percent + 5)) },
            { id: "nightLight",
              adjustLeft:  () => _cycleNightMode(-1),
              adjustRight: () => _cycleNightMode(1) },
        ];
        if (nightOn) list.push({
            id: "temperature",
            adjustLeft:  () => nightManual && _adjustTemp(-100),
            adjustRight: () => nightManual && _adjustTemp(100),
        });
        if (nightAuto) list.push(
            { id: "sunrise", adjustLeft: () => _adjustTime("sunrise", -30), adjustRight: () => _adjustTime("sunrise", 30) },
            { id: "sunset",  adjustLeft: () => _adjustTime("sunset", -30),  adjustRight: () => _adjustTime("sunset", 30) },
        );
        list.push(
            { id: "idle",
              adjustLeft:  () => UserSettings.idleTimeout = Math.max(0, UserSettings.idleTimeout - 5),
              adjustRight: () => UserSettings.idleTimeout = Math.min(60, UserSettings.idleTimeout + 5) },
            { id: "autoClean",
              adjustLeft:  () => UserSettings.notifAutoClean = _cleanValues[Math.max(0, _cleanIndex - 1)],
              adjustRight: () => UserSettings.notifAutoClean = _cleanValues[Math.min(_cleanValues.length - 1, _cleanIndex + 1)] },
            { id: "sysInfo",
              adjustLeft:  () => UserSettings.sysInfoEnabled = !UserSettings.sysInfoEnabled,
              adjustRight: () => UserSettings.sysInfoEnabled = !UserSettings.sysInfoEnabled },
        );
        return list;
    }

    itemCount: items.length
    function _indexOf(id) { for (let i = 0; i < items.length; i++) if (items[i].id === id) return i; return -1; }
    function _dispatch(dir) {
        const item = items[selectedItem];
        if (!item) return false;
        const handler = dir < 0 ? item.adjustLeft : item.adjustRight;
        if (!handler) return false;
        handler();
        return true;
    }
    function adjustLeft()  { return _dispatch(-1); }
    function adjustRight() { return _dispatch(1); }

    function _cycleNightMode(delta) {
        const idx = Math.max(0, Math.min(2, modeIndex + delta));
        UserSettings.nightLightMode = modes[idx];
        UserSettings.applyNightLight();
    }

    function _adjustTemp(delta) {
        UserSettings.nightLightTemp = Math.max(UserSettings.tempMin,
            Math.min(UserSettings.tempMax, UserSettings.nightLightTemp + delta));
        UserSettings.applyNightLight();
    }

    function _adjustTime(which, deltaMin) {
        const current = which === "sunrise" ? UserSettings.nightLightSunrise : UserSettings.nightLightSunset;
        const parts = current.split(":").map(Number);
        let mins = parts[0] * 60 + (parts[1] || 0) + deltaMin;
        if (mins < 0) mins += 1440;
        if (mins >= 1440) mins -= 1440;
        const h = String(Math.floor(mins / 60)).padStart(2, "0");
        const m = String(mins % 60).padStart(2, "0");
        if (which === "sunrise") UserSettings.nightLightSunrise = h + ":" + m;
        else UserSettings.nightLightSunset = h + ":" + m;
        UserSettings.applyNightLight();
    }

    // ── UI ──

    // Brightness
    SettingsRow {
        selected: root.active && root.selectedItem === root._indexOf("brightness")
        Layout.preferredHeight: Theme.settingsRowHeight

        SettingsRow.Icon { text: Theme.iconBrightness; color: Theme.yellow }
        SettingsRow.Label { text: "Brightness"; Layout.preferredWidth: tempLabel.implicitWidth }
        SettingsProgressBar {
            value: Brightness.percent / 100
            barColor: Theme.yellow
        }
        SettingsRow.Value { text: Brightness.percent + "%"; Layout.preferredWidth: 30 }
    }

    Separator {}

    // Night light mode
    SettingsRow {
        selected: root.active && root.selectedItem === root._indexOf("nightLight")
        Layout.preferredHeight: Theme.settingsRowHeight

        SettingsRow.Icon {
            text: Theme.iconNightLight
            color: root.nightOn ? Theme.yellow : Theme.fgDim
        }
        SettingsRow.Label { text: "Night Light"; Layout.fillWidth: true }
        SettingsRow.Value {
            text: root.modes[root.modeIndex].charAt(0).toUpperCase() + root.modes[root.modeIndex].slice(1)
            color: root.nightOn ? Theme.yellow : Theme.fgDim
            Layout.rightMargin: 4
        }
        SkewToggle {
            stateCount: 3
            state: root.modeIndex
        }
    }

    // Temperature (visible when manual or auto, adjustable only in manual mode)
    SettingsRow {
        visible: root.nightOn
        opacity: root.nightAuto ? Theme.opacityMuted : 1.0
        selected: root.active && root.selectedItem === root._indexOf("temperature")
        Layout.preferredHeight: Theme.settingsRowHeight

        SettingsRow.Icon { text: Theme.iconThermometer; color: Theme.yellow }
        SettingsRow.Label { id: tempLabel; text: "Temperature" }
        SettingsProgressBar {
            value: (UserSettings.activeTemp - UserSettings.tempMin) / (UserSettings.tempMax - UserSettings.tempMin)
            barColor: Theme.yellow
        }
        SettingsRow.Value { text: UserSettings.activeTemp + "K"; Layout.preferredWidth: 36 }
    }

    // Sunrise (auto mode only)
    SettingsRow {
        visible: root.nightAuto
        selected: root.active && root.selectedItem === root._indexOf("sunrise")
        Layout.preferredHeight: Theme.settingsRowCompact

        SettingsRow.Icon {
            text: Theme.iconSunrise
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.yellow
        }
        SettingsRow.Label { text: "Sunrise"; Layout.fillWidth: true }
        SettingsRow.Label { text: UserSettings.nightLightSunrise; color: Theme.accent }
    }

    // Sunset (auto mode only)
    SettingsRow {
        visible: root.nightAuto
        selected: root.active && root.selectedItem === root._indexOf("sunset")
        Layout.preferredHeight: Theme.settingsRowCompact

        SettingsRow.Icon {
            text: Theme.iconSunset
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.accent
        }
        SettingsRow.Label { text: "Sunset"; Layout.fillWidth: true }
        SettingsRow.Label {
            text: UserSettings.nightLightSunset
            color: Theme.accent
        }
    }

    Separator {}

    // Auto-lock timeout
    SettingsRow {
        selected: root.active && root.selectedItem === root._indexOf("idle")
        Layout.preferredHeight: Theme.settingsRowHeight

        SettingsRow.Icon {
            text: Theme.iconLock
            color: UserSettings.idleTimeout > 0 ? Theme.accent : Theme.fgDim
        }
        SettingsRow.Label { text: "Auto Lock"; Layout.fillWidth: true }
        SettingsRow.Value {
            text: UserSettings.idleTimeout > 0 ? UserSettings.idleTimeout + " min" : "Off"
            color: UserSettings.idleTimeout > 0 ? Theme.accent : Theme.fgDim
        }
    }

    // Notification auto-clean
    SettingsRow {
        selected: root.active && root.selectedItem === root._indexOf("autoClean")
        Layout.preferredHeight: Theme.settingsRowHeight

        SettingsRow.Icon {
            text: Theme.iconBell
            color: root._cleanIndex > 0 ? Theme.accent : Theme.fgDim
        }
        SettingsRow.Label { text: "Auto Clean"; Layout.fillWidth: true }
        SettingsRow.Value {
            text: root._cleanLabels[root._cleanIndex]
            color: root._cleanIndex > 0 ? Theme.accent : Theme.fgDim
        }
    }

    Separator {}

    // System monitor
    SettingsRow {
        selected: root.active && root.selectedItem === root._indexOf("sysInfo")
        Layout.preferredHeight: Theme.settingsRowHeight

        SettingsRow.Icon {
            text: Theme.iconMonitor
            color: UserSettings.sysInfoEnabled ? Theme.accent : Theme.fgDim
        }
        SettingsRow.Label { text: "System Monitor"; Layout.fillWidth: true }
        SkewToggle {
            state: UserSettings.sysInfoEnabled ? 1 : 0
        }
    }
}
