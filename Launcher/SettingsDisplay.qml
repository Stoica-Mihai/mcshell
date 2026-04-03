import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Core

// Display settings card content — brightness + night light.
ColumnLayout {
    id: root

    property bool active: false

    // ── Header ──
    readonly property string headerIcon: Theme.iconBrightness
    readonly property string headerTitle: "Display"
    readonly property string headerSubtitle: brightnessPct + "%" + (UserSettings.nightLightActive ? " • Night light on" : "")
    readonly property color headerColor: Theme.yellow

    property int brightness: 0
    property int brightnessMax: 1
    readonly property int brightnessPct: brightnessMax > 0
        ? Math.round(brightness / brightnessMax * 100) : 0

    spacing: 4

    // ── Brightness ──
    SafeProcess {
        id: getBri
        command: ["brightnessctl", "get"]
        failMessage: "brightnessctl not found"
        onRead: data => {
            const val = parseInt(data.trim(), 10);
            if (!isNaN(val)) root.brightness = val;
        }
    }
    SafeProcess {
        id: getBriMax
        command: ["brightnessctl", "max"]
        failMessage: "brightnessctl max failed"
        onRead: data => {
            const val = parseInt(data.trim(), 10);
            if (!isNaN(val) && val > 0) root.brightnessMax = val;
        }
    }
    SafeProcess {
        id: setBri
        command: ["brightnessctl", "set", "50%"]
        failMessage: "brightnessctl set failed"
        onFinished: getBri.running = true
    }

    Component.onCompleted: {
        getBri.running = true;
        getBriMax.running = true;
    }

    // ── Keyboard nav ──
    // 0 = brightness, 1 = night light, 2 = temperature (only when night light on)
    property int selectedItem: 0
    readonly property int itemCount: UserSettings.nightLightActive ? 3 : 2
    function resetSelection() { selectedItem = 0; }
    function navigateUp() { if (selectedItem > 0) selectedItem--; }
    function navigateDown() { if (selectedItem < itemCount - 1) selectedItem++; }
    function activateItem() {
        if (selectedItem === 1) toggleNightLight();
    }
    function adjustLeft() {
        if (selectedItem === 0) {
            const pct = Math.max(0, brightnessPct - 5);
            setBri.command = ["brightnessctl", "set", pct + "%"];
            setBri.running = true;
            return true;
        }
        if (selectedItem === 2) {
            setTemp(Math.max(2500, UserSettings.nightLightTemp - 100));
            return true;
        }
        return false;
    }
    function adjustRight() {
        if (selectedItem === 0) {
            const pct = Math.min(100, brightnessPct + 5);
            setBri.command = ["brightnessctl", "set", pct + "%"];
            setBri.running = true;
            return true;
        }
        if (selectedItem === 2) {
            setTemp(Math.min(5500, UserSettings.nightLightTemp + 100));
            return true;
        }
        return false;
    }

    function toggleNightLight() {
        if (UserSettings.nightLightActive) UserSettings.stopNightLight();
        else UserSettings.applyNightLight();
        UserSettings.nightLightActive = !UserSettings.nightLightActive;
    }

    function setTemp(temp) {
        UserSettings.nightLightTemp = temp;
        if (UserSettings.nightLightActive) tempDebounce.restart();
    }

    // Debounce temperature changes — only restart wlsunset after user stops adjusting
    Timer {
        id: tempDebounce
        interval: 400
        onTriggered: UserSettings.applyNightLight()
    }

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
                    width: parent.width * (root.brightnessPct / 100)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.yellow
                }
            }
            Text {
                text: root.brightnessPct + "%"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.fgDim
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // Night light
        SettingsRow {
            selected: root.active && root.selectedItem === 1
            Layout.preferredHeight: 40

            Text {
                text: Theme.iconNightLight
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: UserSettings.nightLightActive ? Theme.yellow : Theme.fgDim
            }
            Text {
                text: "Night Light"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.fg
                Layout.fillWidth: true
            }
            Text {
                text: UserSettings.nightLightActive ? "On" : "Off"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: UserSettings.nightLightActive ? Theme.yellow : Theme.fgDim
            }
        }

        // Temperature (visible only when night light is on)
        SettingsRow {
            visible: UserSettings.nightLightActive
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
                    width: parent.width * ((UserSettings.nightLightTemp - 2500) / 3000)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.yellow
                }
            }
            Text {
                text: UserSettings.nightLightTemp + "K"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.fgDim
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
            }
        }

}
