import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Niri
import qs.Config
import qs.Core

// Power settings card content — lock, logout, reboot, shutdown.
Item {
    id: root

    property bool active: false

    // ── Actions ──
    SafeProcess {
        id: lockProc
        command: ["qs", "-c", "mcshell", "ipc", "call", "mcshell", "lock"]
        failMessage: "lock failed"
    }
    SafeProcess {
        id: rebootProc
        command: ["systemctl", "reboot"]
        failMessage: "reboot failed"
    }
    SafeProcess {
        id: shutdownProc
        command: ["systemctl", "poweroff"]
        failMessage: "shutdown failed"
    }

    readonly property var actions: [
        { name: "Lock", icon: Theme.iconLock, danger: false },
        { name: "Log out", icon: Theme.iconLogout, danger: false },
        { name: "Reboot", icon: Theme.iconReboot, danger: true },
        { name: "Shutdown", icon: Theme.iconShutdown, danger: true },
    ]

    // ── Keyboard nav ──
    property int selectedItem: 0
    function resetSelection() { selectedItem = 0; confirmItem = -1; }
    property int confirmItem: -1  // which item is awaiting confirmation

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: root.confirmItem = -1
    }

    function navigateUp() { if (selectedItem > 0) selectedItem--; }
    function navigateDown() { if (selectedItem < 3) selectedItem++; }

    function activateItem() {
        const action = actions[selectedItem];
        if (action.danger && confirmItem !== selectedItem) {
            confirmItem = selectedItem;
            confirmReset.restart();
            return;
        }
        confirmItem = -1;
        switch (selectedItem) {
        case 0: lockProc.running = true; break;
        case 1: Niri.dispatch(["quit", "--skip-confirmation"]); break;
        case 2: rebootProc.running = true; break;
        case 3: shutdownProc.running = true; break;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Theme.iconShutdown
            font.family: Theme.iconFont
            font.pixelSize: 36
            color: Theme.fg
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Power"
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.bold: true
            color: Theme.fg
        }

        Item { Layout.preferredHeight: 12 }

        Repeater {
            model: root.actions

            Rectangle {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                implicitHeight: 38
                radius: 6
                color: root.active && root.selectedItem === index
                    ? (modelData.danger ? Qt.rgba(0.97, 0.47, 0.56, 0.08) : Theme.overlay)
                    : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Text {
                        text: modelData.icon
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: modelData.danger ? Theme.red : Theme.fg
                    }
                    Text {
                        text: root.confirmItem === index ? "Confirm?" : modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: root.confirmItem === index ? Theme.red
                             : modelData.danger ? Theme.fg : Theme.fg
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: modelData.danger && root.confirmItem !== index
                        text: "confirm"
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: Theme.fgDim
                        opacity: 0.4
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "↑ ↓ select  |  Enter activate"
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: Theme.fgDim
            opacity: 0.5
            Layout.bottomMargin: 8
        }
    }
}
