import QtQuick
import QtQuick.Layouts
import Quickshell
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
    readonly property var _cleanValues: UserSettings.notifAutoCleanOptions.map(o => o.id)
    readonly property var _cleanLabels: UserSettings.notifAutoCleanOptions.map(o => o.label)
    readonly property int _cleanIndex: indexInList(_cleanValues, UserSettings.notifAutoClean)

    // ── Primary output mapping (multi-monitor only) ──
    readonly property var _screenNames: Quickshell.screens.map(s => s.name)
    readonly property bool _multiScreen: Quickshell.screens.length > 1
    readonly property int _primaryIndex: indexInList(_screenNames, UserSettings.primaryOutput)

    // ── Auto-lock mapping ──
    readonly property var _idleOptions: [
        { value: 0,  label: "Off" },
        { value: 5,  label: "5 min" },
        { value: 10, label: "10 min" },
        { value: 15, label: "15 min" },
        { value: 30, label: "30 min" },
        { value: 45, label: "45 min" },
        { value: 60, label: "60 min" }
    ]
    readonly property var _idleValues: _idleOptions.map(o => o.value)
    readonly property var _idleLabels: _idleOptions.map(o => o.label)
    readonly property int _idleIndex: indexInList(_idleValues, UserSettings.idleTimeout)

    // ── Sunrise/sunset time slots (30-min granularity) ──
    readonly property var _timeSlots: {
        const list = [];
        for (let h = 0; h < 24; h++)
            for (let m = 0; m < 60; m += 30)
                list.push(UserSettings.formatHHMM(h * 60 + m));
        return list;
    }
    function _slotIndex(t) { return indexInList(_timeSlots, t); }

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
        if (_multiScreen) list.push({
            id: "primaryOutput",
            adjustLeft:  () => primaryPicker.cycleLeft(),
            adjustRight: () => primaryPicker.cycleRight(),
        });
        list.push(
            { id: "idle",
              adjustLeft:  () => UserSettings.idleTimeout = _idleValues[clampStep(_idleIndex, -1, _idleValues.length)],
              adjustRight: () => UserSettings.idleTimeout = _idleValues[clampStep(_idleIndex, 1, _idleValues.length)] },
            { id: "autoClean",
              adjustLeft:  () => UserSettings.notifAutoClean = _cleanValues[clampStep(_cleanIndex, -1, _cleanValues.length)],
              adjustRight: () => UserSettings.notifAutoClean = _cleanValues[clampStep(_cleanIndex, 1, _cleanValues.length)] },
            { id: "sysInfo",
              adjustLeft:  () => UserSettings.sysInfoEnabled = !UserSettings.sysInfoEnabled,
              adjustRight: () => UserSettings.sysInfoEnabled = !UserSettings.sysInfoEnabled },
        );
        return list;
    }

    itemCount: items.length
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
        const idx = clampStep(modeIndex, delta, modes.length);
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
        const next = UserSettings.formatHHMM(UserSettings.parseHHMM(current) + deltaMin);
        if (which === "sunrise") UserSettings.nightLightSunrise = next;
        else UserSettings.nightLightSunset = next;
        UserSettings.applyNightLight();
    }

    // ── UI ──

    // Brightness
    SettingsRow {
        selected: root.active && root.selectedItem === root.indexInList(root.items, "brightness", "id")

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
        selected: root.active && root.selectedItem === root.indexInList(root.items, "nightLight", "id")

        SettingsRow.Icon {
            text: Theme.iconNightLight
            color: root.nightOn ? Theme.yellow : Theme.fgDim
        }
        SettingsRow.Label { text: "Night Light"; Layout.fillWidth: true }
        SkewToggle {
            stateCount: 3
            state: root.modeIndex
            labels: ["Off", "Manual", "Auto"]
            labelColor: root.nightOn ? Theme.yellow : Theme.fgDim
        }
    }

    // Temperature (visible when manual or auto, adjustable only in manual mode)
    SettingsRow {
        visible: root.nightOn
        opacity: root.nightAuto ? Theme.opacityMuted : 1.0
        selected: root.active && root.selectedItem === root.indexInList(root.items, "temperature", "id")

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
        selected: root.active && root.selectedItem === root.indexInList(root.items, "sunrise", "id")
        Layout.preferredHeight: Theme.settingsRowCompact

        SettingsRow.Icon {
            text: Theme.iconSunrise
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.yellow
        }
        SettingsRow.Label { text: "Sunrise"; Layout.fillWidth: true }
        CyclePicker {
            pillValue: true
            model: root._timeSlots
            currentIndex: root._slotIndex(UserSettings.nightLightSunrise)
            textColor: Theme.yellow
        }
    }

    // Sunset (auto mode only)
    SettingsRow {
        visible: root.nightAuto
        selected: root.active && root.selectedItem === root.indexInList(root.items, "sunset", "id")
        Layout.preferredHeight: Theme.settingsRowCompact

        SettingsRow.Icon {
            text: Theme.iconSunset
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.accent
        }
        SettingsRow.Label { text: "Sunset"; Layout.fillWidth: true }
        CyclePicker {
            pillValue: true
            model: root._timeSlots
            currentIndex: root._slotIndex(UserSettings.nightLightSunset)
            textColor: Theme.accent
        }
    }

    Separator {}

    // Primary output (launcher home monitor; multi-monitor only)
    SettingsRow {
        visible: root._multiScreen
        selected: root.active && root.selectedItem === root.indexInList(root.items, "primaryOutput", "id")

        SettingsRow.Icon { text: Theme.iconMonitor; color: Theme.accent }
        SettingsRow.Label { text: "Primary Output"; Layout.fillWidth: true }
        CyclePicker {
            id: primaryPicker
            pillValue: true
            model: root._screenNames
            currentIndex: root._primaryIndex
            textColor: Theme.accent
            onIndexChanged: idx => UserSettings.primaryOutput = root._screenNames[idx]
        }
    }

    // Auto-lock timeout
    SettingsRow {
        selected: root.active && root.selectedItem === root.indexInList(root.items, "idle", "id")

        SettingsRow.Icon {
            text: Theme.iconLock
            color: UserSettings.idleTimeout > 0 ? Theme.accent : Theme.fgDim
        }
        SettingsRow.Label { text: "Auto Lock"; Layout.fillWidth: true }
        CyclePicker {
            pillValue: true
            model: root._idleLabels
            currentIndex: root._idleIndex
            textColor: UserSettings.idleTimeout > 0 ? Theme.accent : Theme.fgDim
        }
    }

    // Notification auto-clean
    SettingsRow {
        selected: root.active && root.selectedItem === root.indexInList(root.items, "autoClean", "id")

        SettingsRow.Icon {
            text: Theme.iconBell
            color: root._cleanIndex > 0 ? Theme.accent : Theme.fgDim
        }
        SettingsRow.Label { text: "Auto Clean"; Layout.fillWidth: true }
        CyclePicker {
            pillValue: true
            model: root._cleanLabels
            currentIndex: root._cleanIndex
            textColor: root._cleanIndex > 0 ? Theme.accent : Theme.fgDim
        }
    }

    Separator {}

    // System monitor
    SettingsRow {
        selected: root.active && root.selectedItem === root.indexInList(root.items, "sysInfo", "id")

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
