import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Core
import qs.Widgets

// Display settings card content — brightness + night light.
ColumnLayout {
    id: root

    property bool active: false

    // ── Header ──
    readonly property string headerIcon: Theme.iconBrightness
    readonly property string headerTitle: "Display"
    readonly property string panelLegend: Theme.legend(Theme.hintUpDown, Theme.hintAdjust, Theme.hintEnter + " select", Theme.hintBack)
    readonly property string headerSubtitle: {
        const bri = Brightness.percent + "%";
        if (UserSettings.nightLightMode === UserSettings.modeManual) return bri + " • Night light manual";
        if (UserSettings.nightLightMode === UserSettings.modeAuto) return bri + " • Night light auto";
        return bri;
    }
    readonly property color headerColor: Theme.yellow

    spacing: 4

    // ── Night light mode mapping ──
    readonly property var modes: [UserSettings.modeOff, UserSettings.modeManual, UserSettings.modeAuto]
    readonly property int modeIndex: modes.indexOf(UserSettings.nightLightMode)
    readonly property bool nightOn: UserSettings.nightLightMode !== UserSettings.modeOff

    // ── Keyboard nav ──
    // 0 = brightness, 1 = night light toggle, 2 = temperature, 3 = sunrise, 4 = sunset
    property int selectedItem: 0
    readonly property int itemCount: {
        if (!nightOn) return 2;
        if (UserSettings.nightLightMode === UserSettings.modeAuto) return 5; // brightness + toggle + temp(disabled) + sunrise + sunset
        return 3; // on: brightness + toggle + temp
    }
    function resetSelection() { selectedItem = 0; }
    function navigateUp() { if (selectedItem > 0) selectedItem--; }
    function navigateDown() { if (selectedItem < itemCount - 1) selectedItem++; }
    function activateItem() {}
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
            UserSettings.nightLightTemp = Math.max(2500, UserSettings.nightLightTemp - 100);
            UserSettings.applyNightLight();
            return true;
        }
        if (selectedItem === 3 && UserSettings.nightLightMode === UserSettings.modeAuto) { adjustTime("sunrise", -30); return true; }
        if (selectedItem === 4 && UserSettings.nightLightMode === UserSettings.modeAuto) { adjustTime("sunset", -30); return true; }
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
            UserSettings.nightLightTemp = Math.min(5500, UserSettings.nightLightTemp + 100);
            UserSettings.applyNightLight();
            return true;
        }
        if (selectedItem === 3 && UserSettings.nightLightMode === UserSettings.modeAuto) { adjustTime("sunrise", 30); return true; }
        if (selectedItem === 4 && UserSettings.nightLightMode === UserSettings.modeAuto) { adjustTime("sunset", 30); return true; }
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
        Layout.preferredHeight: 40

        Text {
            text: Theme.iconBrightness
            font.family: Theme.iconFont
            font.pixelSize: 14
            color: Theme.yellow
        }
        Text {
            text: "Brightness"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.preferredWidth: 70
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
            font.pixelSize: 10
            color: Theme.fgDim
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

    // Night light mode
    SettingsRow {
        selected: root.active && root.selectedItem === 1
        Layout.preferredHeight: 40

        Text {
            text: Theme.iconNightLight
            font.family: Theme.iconFont
            font.pixelSize: 14
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
            font.pixelSize: 10
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
        opacity: UserSettings.nightLightMode === UserSettings.modeAuto ? 0.5 : 1.0
        selected: root.active && root.selectedItem === 2
        Layout.preferredHeight: 40

        Text {
            text: "\uf2c9"
            font.family: Theme.iconFont
            font.pixelSize: 14
            color: Theme.yellow
        }
        Text {
            text: "Temperature"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.preferredWidth: 70
        }
        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: Theme.overlay
            Rectangle {
                width: parent.width * ((UserSettings.activeTemp - 2500) / 3000)
                height: parent.height
                radius: parent.radius
                color: Theme.yellow
            }
        }
        Text {
            text: UserSettings.activeTemp + "K"
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: Theme.fgDim
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }

    // Sunrise (auto mode only)
    SettingsRow {
        visible: UserSettings.nightLightMode === UserSettings.modeAuto
        selected: root.active && root.selectedItem === 3
        Layout.preferredHeight: 36

        Text {
            text: "\uf185"
            font.family: Theme.iconFont
            font.pixelSize: 12
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
        Layout.preferredHeight: 36

        Text {
            text: "\uf186"
            font.family: Theme.iconFont
            font.pixelSize: 12
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
}
