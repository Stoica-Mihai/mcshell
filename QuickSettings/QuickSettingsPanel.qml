import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.Config
import qs.Widgets

AnimatedPopup {
    id: root

    implicitWidth: 280

    function open(anchorItem) {
        anchor.item = anchorItem;
        anchor.rect.x = -(implicitWidth - anchorItem.width);
        anchor.rect.y = (Theme.barHeight + anchorItem.height) / 2 - 2;
        fullHeight = content.implicitHeight + 24;
        open();  // AnimatedPopup.open()
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

    property bool doNotDisturb: false
    property bool nightLightActive: false

    // ── Poll non-native states on open ──────────────────
    onIsOpenChanged: {
        if (isOpen) {
            nightLightCheck.running = true;
            brightnessSlider.refresh();
        }
    }

    // ── Night light (wlsunset) — no native API ─────────
    Process {
        id: nightLightCheck
        command: ["pgrep", "-x", "wlsunset"]
        stdout: SplitParser {
            onRead: data => {
                root.nightLightActive = data.trim().length > 0;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) root.nightLightActive = false;
        }
    }

    Process {
        id: nightLightOn
        command: ["wlsunset", "-t", "4000", "-T", "6500"]
    }

    Process {
        id: nightLightOff
        command: ["pkill", "-x", "wlsunset"]
    }

    // ── Background ──────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.barRadius
        bottomRightRadius: Theme.barRadius
        color: Theme.bgSolid
        border.width: 1
        border.color: Theme.border
        clip: true

        // Hide top border (it overlaps with bar)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            height: 2
            color: Theme.bgSolid
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

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

            // ── Volume ──────────────────────────────────
            VolumeSlider {
                id: volumeSlider
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 2
            }

            // ── Brightness ─────────────────────────────
            BrightnessSlider {
                id: brightnessSlider
                Layout.fillWidth: true
                Layout.bottomMargin: 2
            }

            // ── App Volumes ────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
                visible: appVolume.hasStreams
            }

            AppVolume {
                id: appVolume
                Layout.fillWidth: true
            }

            // ── Separator ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // ── Wifi toggle ─────────────────────────────
            ToggleRow {
                Layout.fillWidth: true
                icon: root.wifiEnabled ? "\uf1eb" : "\uf467"
                label: "Wi-Fi"
                sublabel: root.wifiEnabled ? (root.wifiSsid !== "" ? root.wifiSsid : "On") : "Off"
                checked: root.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            // ── Bluetooth toggle ────────────────────────
            ToggleRow {
                Layout.fillWidth: true
                icon: root.bluetoothEnabled ? "\uf294" : "\uf294"
                label: "Bluetooth"
                sublabel: root.bluetoothEnabled ? "On" : "Off"
                checked: root.bluetoothEnabled
                onToggled: {
                    if (root.btAdapter)
                        root.btAdapter.enabled = !root.btAdapter.enabled;
                }
            }

            // ── Do Not Disturb ──────────────────────────
            ToggleRow {
                Layout.fillWidth: true
                icon: root.doNotDisturb ? "\uf59a" : "\uf599"
                label: "Do Not Disturb"
                sublabel: root.doNotDisturb ? "On" : "Off"
                checked: root.doNotDisturb
                onToggled: {
                    root.doNotDisturb = !root.doNotDisturb;
                }
            }

            // ── Night Light ─────────────────────────────
            ToggleRow {
                Layout.fillWidth: true
                icon: root.nightLightActive ? "\ue228" : "\ue228"
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
                    toggleRefresh.restart();
                }
            }
        }
    }
}
