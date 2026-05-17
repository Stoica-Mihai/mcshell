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

    // ── Reactive refresh ──
    // Replaces the old 2 s polling loop. Three sources can trigger a
    // refresh — model add/remove (valuesChanged), per-device property
    // changes (connected/paired/name/rssi/battery), and the user's
    // search query (handled by onSearch above). All three funnel into
    // a 350 ms debounce so a BlueZ probe wave doesn't refresh N times.
    readonly property bool _refreshGate:
        root.launcher.isOpen && root.active && root.btReady

    Timer {
        id: _refreshDebounce
        interval: 350
        repeat: false
        onTriggered: if (root._refreshGate) root.refreshBt(root.launcher.searchText)
    }

    // Model-level: device added / removed.
    Connections {
        target: root.btAdapter ? root.btAdapter.devices : null
        enabled: root._refreshGate
        function onValuesChanged() { _refreshDebounce.restart(); }
    }

    // Per-device: properties the carousel renders (connected, paired,
    // name, rssi, battery). Instantiator dynamically tracks the device
    // list so devices joining mid-session get listeners too; the delegate
    // is non-visual — purely a Connections host. `.values` (QVariantList)
    // is what the rest of the shell binds to as well; passing the raw
    // ObjectModel doesn't expose `modelData` consistently in Instantiator.
    Instantiator {
        model: (root.btAdapter && root.btAdapter.devices)
            ? root.btAdapter.devices.values : []
        delegate: Connections {
            required property var modelData
            target: modelData
            enabled: root._refreshGate
            function onConnectedChanged() { _refreshDebounce.restart(); }
            function onPairedChanged()    { _refreshDebounce.restart(); }
            function onNameChanged()      { _refreshDebounce.restart(); }
            function onRssiChanged()      { _refreshDebounce.restart(); }
            function onBatteryChanged()   { _refreshDebounce.restart(); }
        }
    }

    // Track the device we last asked to pair, so we can mirror its state
    // changes into btTracker for the carousel hint text.
    property var _activePairDev: null
    Connections {
        target: _activePairDev
        function onPairedChanged() {
            if (_activePairDev && _activePairDev.paired) {
                btTracker.status = "paired";
                btTracker.autoClear();
                _activePairDev.connect();
            }
        }
        function onPairingChanged() {
            if (_activePairDev && !_activePairDev.pairing && !_activePairDev.paired) {
                btTracker.status = "failed";
                btTracker.autoClear();
                NotificationDispatcher.send(
                    "Bluetooth",
                    `Failed to pair with ${btTracker.targetId}`,
                    Theme.notifNormal,
                    "critical"
                );
            }
        }
        function onConnectedChanged() {
            if (_activePairDev && _activePairDev.connected) {
                btTracker.status = "connected";
                btTracker.autoClear();
            }
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
            _activePairDev = dev;
            dev.connect();
        } else {
            btTracker.status = "pairing";
            _activePairDev = dev;
            // BlueZ routes any pin / passkey / confirmation prompts to our
            // registered Agent1 (Bluetooth.pairingAgent), which the
            // BluetoothPairingDialog renders.
            dev.pair();
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
                    if (UserSettings.bluetoothCardType) {
                        const devType = (root.btDeviceTypes[modelData.icon]?.label) ?? "";
                        if (devType) parts.push(devType);
                    }
                    if (UserSettings.bluetoothCardStatus) {
                        if (modelData.connected) parts.push("Connected");
                        else if (modelData.paired) parts.push("Paired");
                        else parts.push("Available");
                    }
                    if (UserSettings.bluetoothCardBattery && modelData.batteryAvailable)
                        parts.push(Math.round(modelData.battery * 100) + "%");
                    if (UserSettings.bluetoothCardRssi && modelData.rssi !== 0)
                        parts.push(modelData.rssi + " dBm");
                    if (UserSettings.bluetoothCardClass && modelData.bluetoothClass)
                        parts.push("Class 0x" + modelData.bluetoothClass.toString(16).padStart(6, "0"));
                    return parts.join(Theme.separator);
                }

                // MAC address
                Text {
                    visible: UserSettings.bluetoothCardAddress && !!modelData.address
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
