import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Qs.BtHelper
import qs.Config
import qs.Core

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Tab config ──
    tabName: "bluetooth"
    tabLabel: "BT"
    tabIcon: btEnabled ? Theme.iconBluetooth : Theme.iconBluetoothOff
    searchPlaceholder: "Search devices..."
    legendHint: Theme.legend(Theme.hintEnter + " connect", "Ctrl+B toggle Bluetooth")
    disabledLegendHint: "Ctrl+B toggle Bluetooth"

    // ── Disabled state ──
    disabledState: !btEnabled
    disabledIcon: Theme.iconBluetoothOff
    disabledHint: "Ctrl+B to enable"

    // ── Scanning state ──
    scanningState: btEnabled
    scanningIcon: Theme.iconBluetooth
    scanningHint: "Scanning for devices..."

    // ── Data ──
    property bool active: false  // true when this tab is shown
    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter?.enabled ?? false
    readonly property bool btReady: btAdapter?.state === BluetoothAdapter.Enabled
    onBtReadyChanged: {
        if (btReady && active) {
            btAdapter.discovering = true;
            refreshBt();
        }
    }
    onBtEnabledChanged: if (!btEnabled) setItems([])

    StatusTracker { id: btTracker }

    // ── Lifecycle ──
    Connections {
        target: BtHelper
        function onPropertiesRefreshed() {
            if (!root.active) return;
            if (root.btReady) {
                root.btAdapter.discovering = true;
                root.refreshBt();
            } else {
                root.setItems([]);
            }
        }
    }

    function onTabEnter() {
        active = true;
        // Force D-Bus property re-read — bindings may be stale while launcher was hidden
        if (btAdapter) BtHelper.refreshAdapter(btAdapter);
    }

    function onTabLeave() {
        active = false;
        if (btAdapter) btAdapter.discovering = false;
    }

    // ── Search ──
    function onSearch(text) { refreshBt(text); }

    function refreshBt(searchText) {
        if (!btAdapter || !btAdapter.devices) { setItems([]); return; }
        const devs = filterByQuery(searchText, btAdapter.devices.values,
            (d, q) => (d.name || d.deviceName || "").toLowerCase().indexOf(q) >= 0);
        setItems(sortByConnected(devs, d => d.connected, (a, b) => {
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return (a.name || "").localeCompare(b.name || "");
        }));
    }

    // ── Polling timer (BT devices don't rebind Connections target) ──
    Timer {
        interval: 2000
        running: root.active && root.btReady
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
                btTracker.status = line === "CONNECTED" ? "connected" : "paired";
                btTracker.autoClear();
            } else if (line === "FAILED") {
                btTracker.status = "failed";
                btTracker.autoClear();
                NotificationDispatcher.send("Bluetooth", `Failed to connect to ${btTracker.targetId}`, Theme.notifNormal, "critical");
            }
        }
        onFailed: {
            btTracker.status = "failed";
            btTracker.autoClear();
        }
    }



    // ── Device type data ──
    readonly property var btDeviceTypes: ({
        "audio-headset":    { icon: "\u{f01d2}", label: "Headset" },
        "audio-headphones": { icon: "\u{f02cb}", label: "Headphones" },
        "audio-card":       { icon: "\u{f04c3}", label: "Speaker" },
        "input-gaming":     { icon: "\u{f0eb5}", label: "Controller" },
        "input-keyboard":   { icon: "\uf11c",    label: "Keyboard" },
        "input-mouse":      { icon: "\u{f037d}", label: "Mouse" },
        "input-tablet":     { icon: "\u{f04f7}", label: "Tablet" },
        "phone":            { icon: "\u{f03f2}", label: "Phone" },
        "computer":         { icon: "\u{f0379}", label: "Computer" }
    })

    function btDeviceIcon(iconType) {
        return (btDeviceTypes[iconType]?.icon) ?? Theme.iconBluetooth;
    }

    // ── Key handler ──
    function onKeyPressed(event) {
        if (event.key === Qt.Key_B && (event.modifiers & Qt.ControlModifier)
                && !event.isAutoRepeat && btAdapter) {
            btAdapter.enabled = !btAdapter.enabled;
            return true;
        }
        return false;
    }

    // ── Activate ──
    function onActivate(index) {
        if (!_validIndex(index)) return;
        const dev = _sourceData[index];
        btTracker.targetId = dev.address;
        if (dev.connected) {
            btTracker.status = "disconnecting";
            dev.disconnect();
            btTracker.autoClear();
        } else if (dev.paired) {
            btTracker.status = "connecting";
            dev.connect();
            btTracker.autoClear();
        } else {
            btTracker.status = "pairing";
            btPairProc.command = [Quickshell.env("HOME") + "/.config/quickshell/mcshell/Core/bt-pair.sh", dev.address];
            btPairProc.running = true;
        }
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            launcher: root.launcher

            // Collapsed: device type icon
            Text {
                anchors.centerIn: parent
                visible: !parent.isCurrent
                text: root.btDeviceIcon(modelData.icon)
                font.family: Theme.iconFont
                font.pixelSize: Theme.launcherIconCollapsed
                color: modelData.connected ? Theme.accent : Theme.fgDim
            }

            // Expanded: device details
            DeviceCardBody {
                anchors.centerIn: parent
                visible: parent.isCurrent
                width: parent.width - 40

                iconText: root.btDeviceIcon(modelData.icon)
                iconColor: modelData.connected ? Theme.accent : Theme.fg
                nameText: modelData.name || modelData.deviceName || "Unknown"
                nameColor: modelData.connected ? Theme.accent : Theme.fg
                infoText: {
                    const parts = [];
                    const devType = (root.btDeviceTypes[modelData.icon]?.label) ?? "";
                    if (devType) parts.push(devType);
                    if (modelData.connected) parts.push("Connected");
                    else if (modelData.paired) parts.push("Paired");
                    else parts.push("Available");
                    if (modelData.batteryAvailable)
                        parts.push(Math.round(modelData.battery * 100) + "%");
                    return parts.join(Theme.separator);
                }

                // MAC address
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fgDim
                    opacity: Theme.opacityDim
                    text: modelData.address || ""
                }

                StatusHintText {
                    tracker: btTracker
                    targetId: modelData.address || ""
                    successStatuses: ["connected", "paired"]
                    statusLabels: ({
                        "pairing": "Pairing...",
                        "connecting": "Connecting...",
                        "disconnecting": "Disconnecting...",
                        "connected": "Connected",
                        "paired": "Paired",
                        "failed": "Failed"
                    })
                    defaultText: modelData.connected ? "Enter to disconnect"
                        : modelData.paired ? "Enter to connect"
                        : "Enter to pair"
                }
            }
        }
    }
}
