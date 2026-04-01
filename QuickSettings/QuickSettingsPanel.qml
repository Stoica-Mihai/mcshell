import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Niri
import qs.Core
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.Config
import qs.Widgets

// Quick settings content panel.
// Meant to be hosted inside a shared dropdown.
Item {
    id: root

    anchors.fill: parent
    implicitHeight: content.implicitHeight + 24

    property bool panelVisible: false
    signal closeRequested()
    onPanelVisibleChanged: {
        if (panelVisible) {
            nightLightCheck.running = true;
            brightnessSlider.refresh();
        } else {
            rebootCol.confirming = false;
            shutdownCol.confirming = false;
        }
    }

    // ── Native API state (reactive, no polling) ─────────
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property string wifiSsid: {
        if (!Networking.wifiEnabled) return "";
        const devs = Networking.devices?.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            const dev = devs[i];
            if (dev.type === DeviceType.Wifi && dev.connected) {
                const nets = dev.networks?.values ?? [];
                for (let j = 0; j < nets.length; j++) {
                    if (nets[j].connected) return nets[j].name;
                }
            }
        }
        return "";
    }

    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: btAdapter?.enabled ?? false

    property bool nightLightActive: false


    // ── Power actions ──────────────────────────────────
    SafeProcess {
        id: lockProc
        command: ["qs", "-c", "mcshell", "ipc", "call", "mcshell", "lock"]
        failMessage: "lock failed"
    }

    function logoutSession() { Niri.dispatch(["quit", "--skip-confirmation"]); }

    SafeProcess {
        id: rebootSystem
        command: ["systemctl", "reboot"]
        failMessage: "reboot failed"
    }

    SafeProcess {
        id: shutdownSystem
        command: ["systemctl", "poweroff"]
        failMessage: "shutdown failed"
    }

    // ── Night light (wlsunset) — no native API ─────────
    SafeProcess {
        id: nightLightCheck
        command: ["pgrep", "-x", "wlsunset"]
        onRead: data => {
            root.nightLightActive = data.trim().length > 0;
        }
        onFailed: root.nightLightActive = false
    }

    SafeProcess {
        id: nightLightOn
        command: ["wlsunset", "-t", "4000", "-T", "6500"]
        failMessage: "wlsunset not found — night light unavailable"
    }

    SafeProcess {
        id: nightLightOff
        command: ["pkill", "-x", "wlsunset"]
        failMessage: "failed to stop wlsunset"
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 4

            // ── Power Row ──────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                spacing: 0

                Item { Layout.fillWidth: true }

                // Lock
                ColumnLayout {
                    spacing: 2
                    IconButton {
                        Layout.alignment: Qt.AlignHCenter
                        icon: Theme.iconLock
                        size: 18
                        onClicked: {
                            root.closeRequested();
                            lockProc.running = true;
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Lock"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                Item { Layout.fillWidth: true }

                // Logout
                ColumnLayout {
                    spacing: 2
                    IconButton {
                        Layout.alignment: Qt.AlignHCenter
                        icon: Theme.iconLogout
                        size: 18
                        onClicked: root.logoutSession()
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Logout"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                Item { Layout.fillWidth: true }

                // Reboot (with confirmation)
                ColumnLayout {
                    id: rebootCol
                    spacing: 2
                    property bool confirming: false

                    Timer {
                        id: rebootResetTimer
                        interval: 3000
                        onTriggered: rebootCol.confirming = false
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignHCenter
                        icon: Theme.iconReboot
                        size: 18
                        normalColor: rebootCol.confirming ? Theme.red : Theme.fg
                        hoverColor: rebootCol.confirming ? Theme.red : Theme.accent
                        onClicked: {
                            if (rebootCol.confirming) {
                                rebootSystem.running = true;
                            } else {
                                rebootCol.confirming = true;
                                rebootResetTimer.restart();
                            }
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: rebootCol.confirming ? "Sure?" : "Reboot"
                        color: rebootCol.confirming ? Theme.red : Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                Item { Layout.fillWidth: true }

                // Shutdown (with confirmation)
                ColumnLayout {
                    id: shutdownCol
                    spacing: 2
                    property bool confirming: false

                    Timer {
                        id: shutdownResetTimer
                        interval: 3000
                        onTriggered: shutdownCol.confirming = false
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignHCenter
                        icon: Theme.iconShutdown
                        size: 18
                        normalColor: shutdownCol.confirming ? Theme.red : Theme.fg
                        hoverColor: shutdownCol.confirming ? Theme.red : Theme.accent
                        onClicked: {
                            if (shutdownCol.confirming) {
                                shutdownSystem.running = true;
                            } else {
                                shutdownCol.confirming = true;
                                shutdownResetTimer.restart();
                            }
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: shutdownCol.confirming ? "Sure?" : "Shutdown"
                        color: shutdownCol.confirming ? Theme.red : Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // ── Separator (power row / quick settings) ─
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
                Layout.bottomMargin: 2
            }

            // ── Header ──────────────────────────────────
            Text {
                text: "Quick Settings"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
                Layout.fillWidth: true
                Layout.bottomMargin: 4
            }

            // ── Separator ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // ── Brightness ─────────────────────────────
            BrightnessSlider {
                id: brightnessSlider
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 2
            }

            // ── Separator ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }




            // ── Night Light ─────────────────────────────
            ToggleRow {
                Layout.fillWidth: true
                icon: Theme.iconNightLight
                label: "Night Light"
                sublabel: root.nightLightActive ? "On" : "Off"
                checked: root.nightLightActive
                onToggled: {
                    if (root.nightLightActive) {
                        nightLightOff.running = true;
                    } else {
                        nightLightOn.running = true;
                    }
                    root.nightLightActive = !root.nightLightActive;
                }
            }
        }
}
