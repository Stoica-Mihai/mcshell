import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.Config
import qs.Core

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Tab config ──
    tabLabel: "BT"
    tabIcon: Theme.iconBluetooth
    searchPlaceholder: "Search devices..."
    legendHint: "Enter connect  |  Ctrl+B toggle Bluetooth"
    disabledLegendHint: "Ctrl+B toggle Bluetooth"

    // ── Disabled state ──
    disabledState: !btEnabled
    disabledIcon: Theme.iconBluetooth
    disabledHint: "Ctrl+B to enable"

    // ── Scanning state ──
    scanningState: btEnabled
    scanningIcon: Theme.iconBluetooth
    scanningHint: "Scanning for devices..."

    // ── Data ──
    model: filteredBtDevices

    property var filteredBtDevices: []
    property bool active: false  // true when this tab is shown
    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter?.enabled ?? false
    onBtEnabledChanged: if (!btEnabled) filteredBtDevices = []

    property string btStatus: ""         // "" | "pairing" | "connecting" | "disconnecting" | "paired" | "connected" | "failed"
    property string btStatusDevice: ""   // MAC address

    // ── Lifecycle ──
    function onTabEnter() {
        active = true;
        if (btAdapter) btAdapter.discovering = true;
        refreshBt();
    }

    function onTabLeave() {
        active = false;
        if (btAdapter) btAdapter.discovering = false;
    }

    // ── Search ──
    function onSearch(text) { refreshBt(text); }

    function refreshBt(searchText) {
        if (!btAdapter || !btAdapter.devices) { filteredBtDevices = []; return; }
        const devs = [];
        const values = btAdapter.devices.values;
        const q = (searchText !== undefined ? searchText : "").toLowerCase();
        for (let i = 0; i < values.length; i++) {
            const d = values[i];
            const name = d.name || d.deviceName || "";
            if (q === "" || name.toLowerCase().indexOf(q) >= 0)
                devs.push(d);
        }
        devs.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return (a.name || "").localeCompare(b.name || "");
        });
        filteredBtDevices = devs;
    }

    // ── Polling timer (BT devices don't rebind Connections target) ──
    Timer {
        interval: 2000
        running: root.active && root.btEnabled
        repeat: true
        onTriggered: root.refreshBt(root.launcher.searchText)
    }

    // ── Processes ──
    SafeProcess {
        id: btPairProc
        failMessage: "Bluetooth pairing failed"
        onRead: data => {
            const line = data.trim();
            if (line === "PAIRED" || line === "CONNECTED") {
                root.btStatus = line === "CONNECTED" ? "connected" : "paired";
                btStatusClear.start();
            } else if (line === "FAILED") {
                root.btStatus = "failed";
                btStatusClear.start();
            }
        }
        onFailed: {
            root.btStatus = "failed";
            btStatusClear.start();
        }
    }

    Timer {
        id: btStatusClear
        interval: 3000
        onTriggered: { root.btStatus = ""; root.btStatusDevice = ""; }
    }

    // Watch for connect/disconnect completion
    onFilteredBtDevicesChanged: {
        if (btStatusDevice === "" || btStatus === "") return;
        for (let i = 0; i < filteredBtDevices.length; i++) {
            const d = filteredBtDevices[i];
            if (d.address !== btStatusDevice) continue;
            if (btStatus === "connecting" && d.connected) {
                btStatus = "connected"; btStatusClear.start();
            } else if (btStatus === "disconnecting" && !d.connected) {
                btStatus = ""; btStatusDevice = "";
            }
        }
    }

    // ── Device icon helper ──
    function btDeviceIcon(iconType) {
        switch (iconType) {
        case "audio-headset":   return "\u{f01d2}"; // nf-md-headset
        case "audio-headphones": return "\u{f02cb}"; // nf-md-headphones
        case "audio-card":      return "\u{f04c3}"; // nf-md-speaker
        case "input-gaming":    return "\u{f0eb5}"; // nf-md-controller
        case "input-keyboard":  return "\uf11c";     // nf-fa-keyboard
        case "input-mouse":     return "\u{f037d}"; // nf-md-mouse
        case "input-tablet":    return "\u{f04f7}"; // nf-md-tablet
        case "phone":           return "\u{f03f2}"; // nf-md-phone
        case "computer":        return "\u{f0379}"; // nf-md-monitor
        default:                return Theme.iconBluetooth;
        }
    }

    // ── Key handler ──
    function onKeyPressed(event) {
        if (event.key === Qt.Key_B && (event.modifiers & Qt.ControlModifier) && btAdapter) {
            btAdapter.enabled = !btAdapter.enabled;
            return true;
        }
        return false;
    }

    // ── Activate ──
    function onActivate(index) {
        if (index < 0 || index >= filteredBtDevices.length) return;
        const dev = filteredBtDevices[index];
        btStatusDevice = dev.address;
        if (dev.connected) {
            btStatus = "disconnecting";
            dev.disconnect();
            btStatusClear.start();
        } else if (dev.paired) {
            btStatus = "connecting";
            dev.connect();
            btStatusClear.start();
        } else {
            btStatus = "pairing";
            btPairProc.command = [Quickshell.env("HOME") + "/.config/quickshell/mcshell/Core/bt-pair.sh", dev.address];
            btPairProc.running = true;
        }
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            selectedIndex: root.launcher.selectedIndex
            sideCount: root.launcher.sideCount
            expandedWidth: root.launcher.expandedWidth
            stripWidth: root.launcher.stripWidth
            carouselHeight: root.launcher.carouselHeight
            focused: root.launcher.editMode
            onActivated: root.onActivate(index)
            onSelected: root.launcher.selectedIndex = index

            // Collapsed: device type icon
            Text {
                anchors.centerIn: parent
                visible: !parent.isCurrent
                text: root.btDeviceIcon(modelData.icon)
                font.family: Theme.iconFont
                font.pixelSize: 24
                color: modelData.connected ? Theme.accent : Theme.fgDim
            }

            // Expanded: device details
            ColumnLayout {
                anchors.centerIn: parent
                visible: parent.isCurrent
                spacing: 10
                width: parent.width - 40

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.btDeviceIcon(modelData.icon)
                    font.family: Theme.iconFont
                    font.pixelSize: 48
                    color: modelData.connected ? Theme.accent : Theme.fg
                }

                // Device name
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.name || modelData.deviceName || "Unknown"
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                    color: modelData.connected ? Theme.accent : Theme.fg
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width
                }

                // Info: type + status + battery
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fgDim
                    text: {
                        const parts = [];
                        // Device type from icon property
                        const typeMap = {
                            "audio-headset": "Headset",
                            "audio-headphones": "Headphones",
                            "audio-card": "Speaker",
                            "input-gaming": "Controller",
                            "input-keyboard": "Keyboard",
                            "input-mouse": "Mouse",
                            "input-tablet": "Tablet",
                            "phone": "Phone",
                            "computer": "Computer",
                        };
                        const devType = typeMap[modelData.icon] || "";
                        if (devType) parts.push(devType);
                        if (modelData.connected) parts.push("Connected");
                        else if (modelData.paired) parts.push("Paired");
                        else parts.push("Available");
                        if (modelData.batteryAvailable)
                            parts.push(Math.round(modelData.battery * 100) + "%");
                        return parts.join("  •  ");
                    }
                }

                // MAC address
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: Theme.fgDim
                    opacity: 0.4
                    text: modelData.address || ""
                }

                // Action hint / status
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    property bool isTarget: root.btStatusDevice === modelData.address
                    color: isTarget && root.btStatus === "failed" ? Theme.red
                         : isTarget && (root.btStatus === "connected" || root.btStatus === "paired") ? Theme.green
                         : isTarget && root.btStatus !== "" ? Theme.accent
                         : Theme.fgDim
                    opacity: isTarget && root.btStatus !== "" ? 1.0 : 0.6
                    text: {
                        if (isTarget) {
                            if (root.btStatus === "pairing") return "Pairing...";
                            if (root.btStatus === "connecting") return "Connecting...";
                            if (root.btStatus === "disconnecting") return "Disconnecting...";
                            if (root.btStatus === "connected") return "Connected";
                            if (root.btStatus === "paired") return "Paired";
                            if (root.btStatus === "failed") return "Failed";
                        }
                        return modelData.connected ? "Enter to disconnect"
                            : modelData.paired ? "Enter to connect"
                            : "Enter to pair";
                    }
                }
            }
        }
    }
}
