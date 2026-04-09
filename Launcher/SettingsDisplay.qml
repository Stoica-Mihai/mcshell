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
        const bri = Brightness.percent + "%";
        const parts = [];
        if (UserSettings.nightLightMode === UserSettings.modeManual) parts.push("Night light manual");
        else if (UserSettings.nightLightMode === UserSettings.modeAuto) parts.push("Night light auto");
        if (UserSettings.idleTimeout > 0) parts.push("Lock " + UserSettings.idleTimeout + "m");
        if (UserSettings.notifAutoClean !== "never") parts.push("Clean " + UserSettings.notifAutoClean);
        return parts.length > 0 ? bri + Theme.separator + parts.join(Theme.separator) : bri;
    }
    readonly property color headerColor: Theme.yellow

    // ── Night light mode mapping ──
    readonly property var modes: [UserSettings.modeOff, UserSettings.modeManual, UserSettings.modeAuto]
    readonly property int modeIndex: modes.indexOf(UserSettings.nightLightMode)
    readonly property bool nightOn: UserSettings.nightLightMode !== UserSettings.modeOff

    // ── Notification auto-clean mapping ──
    readonly property var _cleanValues: ["never", "30m", "1h", "6h", "24h"]
    readonly property var _cleanLabels: ["Never", "30 min", "1 hour", "6 hours", "24 hours"]
    readonly property int _cleanIndex: Math.max(0, _cleanValues.indexOf(UserSettings.notifAutoClean))

    // 0 = brightness, 1 = night light toggle, 2 = temperature, 3 = sunrise, 4 = sunset, then idle, then auto-clean
    readonly property int _idleItem: {
        if (!nightOn) return 2;
        if (UserSettings.nightLightMode === UserSettings.modeAuto) return 5;
        return 3;
    }
    readonly property int _cleanItem: _idleItem + 1
    itemCount: _cleanItem + 1
    function adjustLeft() {
        if (selectedItem === 0) {
            Brightness.set(Math.max(0, Brightness.percent - 5));
            return true;
        }
        if (selectedItem === 1) {
            const idx = Math.max(0, modeIndex - 1);
            UserSettings.nightLightMode = modes[idx];
            UserSettings.applyNightLight();
            return true;
        }
        if (selectedItem === 2 && UserSettings.nightLightMode === UserSettings.modeManual) {
            UserSettings.nightLightTemp = Math.max(UserSettings.tempMin, UserSettings.nightLightTemp - 100);
            UserSettings.applyNightLight();
            return true;
        }
        if (selectedItem === 3 && UserSettings.nightLightMode === UserSettings.modeAuto) { adjustTime("sunrise", -30); return true; }
        if (selectedItem === 4 && UserSettings.nightLightMode === UserSettings.modeAuto) { adjustTime("sunset", -30); return true; }
        if (selectedItem === _idleItem) { UserSettings.idleTimeout = Math.max(0, UserSettings.idleTimeout - 5); return true; }
        if (selectedItem === _cleanItem) { UserSettings.notifAutoClean = _cleanValues[Math.max(0, _cleanIndex - 1)]; return true; }
        return false;
    }
    function adjustRight() {
        if (selectedItem === 0) {
            Brightness.set(Math.min(100, Brightness.percent + 5));
            return true;
        }
        if (selectedItem === 1) {
            const idx = Math.min(2, modeIndex + 1);
            UserSettings.nightLightMode = modes[idx];
            UserSettings.applyNightLight();
            return true;
        }
        if (selectedItem === 2 && UserSettings.nightLightMode === UserSettings.modeManual) {
            UserSettings.nightLightTemp = Math.min(UserSettings.tempMax, UserSettings.nightLightTemp + 100);
            UserSettings.applyNightLight();
            return true;
        }
        if (selectedItem === 3 && UserSettings.nightLightMode === UserSettings.modeAuto) { adjustTime("sunrise", 30); return true; }
        if (selectedItem === 4 && UserSettings.nightLightMode === UserSettings.modeAuto) { adjustTime("sunset", 30); return true; }
        if (selectedItem === _idleItem) { UserSettings.idleTimeout = Math.min(60, UserSettings.idleTimeout + 5); return true; }
        if (selectedItem === _cleanItem) { UserSettings.notifAutoClean = _cleanValues[Math.min(_cleanValues.length - 1, _cleanIndex + 1)]; return true; }
        return false;
    }

    function adjustTime(which, deltaMin) {
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
        selected: root.active && root.selectedItem === 0
        Layout.preferredHeight: Theme.settingsRowHeight

        Text {
            text: Theme.iconBrightness
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.yellow
        }
        Text {
            text: "Brightness"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.preferredWidth: tempLabel.implicitWidth
        }
        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: Theme.overlay
            Rectangle {
                width: parent.width * (Brightness.percent / 100)
                height: parent.height
                radius: parent.radius
                color: Theme.yellow
            }
        }
        Text {
            text: Brightness.percent + "%"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.fgDim
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    Separator {}

    // Night light mode
    SettingsRow {
        selected: root.active && root.selectedItem === 1
        Layout.preferredHeight: Theme.settingsRowHeight

        Text {
            text: Theme.iconNightLight
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: root.nightOn ? Theme.yellow : Theme.fgDim
        }
        Text {
            text: "Night Light"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
        Text {
            text: root.modes[root.modeIndex].charAt(0).toUpperCase() + root.modes[root.modeIndex].slice(1)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
            color: root.nightOn ? Theme.yellow : Theme.fgDim
            Layout.rightMargin: 4
        }
        TriToggle {
            state: root.modeIndex
            onChanged: newState => {
                UserSettings.nightLightMode = root.modes[newState];
                UserSettings.applyNightLight();
            }
        }
    }

    // Temperature (visible when manual or auto, adjustable only in manual mode)
    SettingsRow {
        visible: root.nightOn
        opacity: UserSettings.nightLightMode === UserSettings.modeAuto ? Theme.opacityMuted : 1.0
        selected: root.active && root.selectedItem === 2
        Layout.preferredHeight: Theme.settingsRowHeight

        Text {
            text: Theme.iconThermometer
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.yellow
        }
        Text {
            id: tempLabel
            text: "Temperature"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
        }
        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: Theme.overlay
            Rectangle {
                width: parent.width * ((UserSettings.activeTemp - UserSettings.tempMin) / (UserSettings.tempMax - UserSettings.tempMin))
                height: parent.height
                radius: parent.radius
                color: Theme.yellow
            }
        }
        Text {
            text: UserSettings.activeTemp + "K"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.fgDim
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }

    // Sunrise (auto mode only)
    SettingsRow {
        visible: UserSettings.nightLightMode === UserSettings.modeAuto
        selected: root.active && root.selectedItem === 3
        Layout.preferredHeight: Theme.settingsRowCompact

        Text {
            text: Theme.iconSunrise
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.yellow
        }
        Text {
            text: "Sunrise"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
        Text {
            text: UserSettings.nightLightSunrise
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.accent
        }
    }

    // Sunset (auto mode only)
    SettingsRow {
        visible: UserSettings.nightLightMode === UserSettings.modeAuto
        selected: root.active && root.selectedItem === 4
        Layout.preferredHeight: Theme.settingsRowCompact

        Text {
            text: Theme.iconSunset
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.accent
        }
        Text {
            text: "Sunset"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
        Text {
            text: UserSettings.nightLightSunset
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.accent
        }
    }

    Separator {}

    // Auto-lock timeout
    SettingsRow {
        selected: root.active && root.selectedItem === root._idleItem
        Layout.preferredHeight: Theme.settingsRowHeight

        Text {
            text: Theme.iconLock
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: UserSettings.idleTimeout > 0 ? Theme.accent : Theme.fgDim
        }
        Text {
            text: "Auto Lock"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
        Text {
            text: UserSettings.idleTimeout > 0 ? UserSettings.idleTimeout + " min" : "Off"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
            color: UserSettings.idleTimeout > 0 ? Theme.accent : Theme.fgDim
        }
    }

    // Notification auto-clean
    SettingsRow {
        selected: root.active && root.selectedItem === root._cleanItem
        Layout.preferredHeight: Theme.settingsRowHeight

        Text {
            text: Theme.iconBell
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: root._cleanIndex > 0 ? Theme.accent : Theme.fgDim
        }
        Text {
            text: "Auto Clean"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
        Text {
            text: root._cleanLabels[root._cleanIndex]
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
            color: root._cleanIndex > 0 ? Theme.accent : Theme.fgDim
        }
    }
}
