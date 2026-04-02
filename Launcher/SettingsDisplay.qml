import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Config
import qs.Core

// Display settings card content — brightness + night light.
Item {
    id: root

    property bool active: false
    property int brightness: 0
    property int brightnessMax: 1
    property bool nightLightActive: false

    readonly property int brightnessPct: brightnessMax > 0
        ? Math.round(brightness / brightnessMax * 100) : 0

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

    // ── Night light ──
    SafeProcess {
        id: nightCheck
        command: ["pgrep", "-x", "wlsunset"]
        onRead: data => root.nightLightActive = data.trim().length > 0
        onFailed: root.nightLightActive = false
    }
    SafeProcess {
        id: nightOn
        command: ["wlsunset", "-t", "4000", "-T", "6500"]
        failMessage: "wlsunset not found"
    }
    SafeProcess {
        id: nightOff
        command: ["pkill", "-x", "wlsunset"]
        failMessage: "failed to stop wlsunset"
    }

    onActiveChanged: {
        if (active) {
            getBri.running = true;
            getBriMax.running = true;
            nightCheck.running = true;
        }
    }

    // ── Keyboard nav ──
    property int selectedItem: 0  // 0 = brightness, 1 = night light
    function resetSelection() { selectedItem = 0; }
    function navigateUp() { if (selectedItem > 0) selectedItem--; }
    function navigateDown() { if (selectedItem < 1) selectedItem++; }
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
        return false;
    }
    function adjustRight() {
        if (selectedItem === 0) {
            const pct = Math.min(100, brightnessPct + 5);
            setBri.command = ["brightnessctl", "set", pct + "%"];
            setBri.running = true;
            return true;
        }
        return false;
    }

    function toggleNightLight() {
        if (nightLightActive) nightOff.running = true;
        else nightOn.running = true;
        nightLightActive = !nightLightActive;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Theme.iconBrightness
            font.family: Theme.iconFont
            font.pixelSize: 36
            color: Theme.yellow
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Display"
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.bold: true
            color: Theme.fg
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.brightnessPct + "%" + (root.nightLightActive ? " • Night light on" : "")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fgDim
        }

        Item { Layout.preferredHeight: 8 }

        // Brightness
        SettingsRow {
            selected: root.active && root.selectedItem === 0
            implicitHeight: 40

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
            implicitHeight: 40

            Text {
                text: Theme.iconNightLight
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: root.nightLightActive ? Theme.yellow : Theme.fgDim
            }
            Text {
                text: "Night Light"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.fg
                Layout.fillWidth: true
            }
            Text {
                text: root.nightLightActive ? "On" : "Off"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: root.nightLightActive ? Theme.yellow : Theme.fgDim
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.selectedItem === 0 ? "← → adjust brightness" : "Enter to toggle"
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: Theme.fgDim
            opacity: 0.5
            Layout.bottomMargin: 8
        }
    }
}
