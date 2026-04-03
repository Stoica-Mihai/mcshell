import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Niri
import qs.Config
import qs.Core

// Power settings card content — lock, logout, reboot, shutdown.
SettingsPanel {
    id: root

    // ── Header ──
    readonly property string headerIcon: Theme.iconShutdown
    readonly property string headerTitle: "Power"
    readonly property string panelLegend: Theme.legend(Theme.hintUpDown, Theme.hintEnter + " activate", Theme.hintBack)
    readonly property string headerSubtitle: ""
    readonly property color headerColor: Theme.fg

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

    itemCount: 4
    function resetSelection() { selectedItem = 0; confirmItem = -1; }
    property int confirmItem: -1  // which item is awaiting confirmation

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: root.confirmItem = -1
    }

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

    Repeater {
            model: root.actions

            SettingsRow {
                required property var modelData
                required property int index
                selected: root.active && root.selectedItem === index
                selectedColor: modelData.danger ? Qt.rgba(0.97, 0.47, 0.56, 0.08) : Theme.overlay

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
