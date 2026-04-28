import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.Config
import qs.Core
import qs.Widgets

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Tab config ──
    tabName: "wifi"
    tabLabel: "WiFi"
    tabIcon: Networking.wifiEnabled ? Theme.iconWifi : Theme.iconWifiOff
    searchPlaceholder: "Search networks..."
    legendHint: Theme.legend(Theme.hintEnter + " connect", "Ctrl+W toggle WiFi")
    disabledLegendHint: "Ctrl+W toggle WiFi"

    // ── Disabled state ──
    disabledState: !Networking.wifiEnabled
    disabledIcon: Theme.iconWifiOff
    disabledHint: "Ctrl+W to enable"

    // ── Scanning state ──
    scanningState: Networking.wifiEnabled
    scanningIcon: Theme.iconWifi
    scanningHint: "Scanning for networks..."

    // ── Data ──
    property string wifiPasswordSsid: ""  // which network is showing password input

    StatusTracker { id: wifiTracker }

    readonly property var wifiDevice: {
        const devs = Networking.devices?.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i];
        }
        return null;
    }

    // ── Frequency helpers ──
    // NM AccessPoint Frequency is in MHz.
    function _wifiBand(mhz) {
        if (!mhz || mhz < 1) return "";
        if (mhz < 3000) return "2.4 GHz";
        if (mhz < 5950) return "5 GHz";
        if (mhz < 7250) return "6 GHz";
        return mhz + " MHz";
    }

    function _wifiChannel(mhz) {
        if (!mhz || mhz < 1) return "";
        if (mhz === 2484) return "14";  // 802.11b/g 14
        if (mhz < 3000) return Math.round((mhz - 2407) / 5).toString();
        if (mhz >= 5170 && mhz <= 5895) return Math.round((mhz - 5000) / 5).toString();
        if (mhz >= 5945 && mhz <= 7125) return Math.round((mhz - 5950) / 5 + 1).toString();
        return "";
    }

    // ── Lifecycle ──
    function onTabEnter() {
        if (wifiDevice) wifiDevice.scannerEnabled = true;
        refreshWifi();
    }

    function onTabLeave() {
        if (wifiDevice) wifiDevice.scannerEnabled = false;
        wifiPasswordSsid = "";
    }

    // ── Search ──
    function onSearch(text) { refreshWifi(text); }

    function refreshWifi(searchText) {
        if (!wifiDevice || !wifiDevice.networks) { setItems([]); return; }
        const nets = filterByQuery(searchText, wifiDevice.networks.values,
            (n, q) => (n.name || "").toLowerCase().indexOf(q) >= 0);
        setItems(sortByConnected(nets, n => n.connected,
            (a, b) => b.signalStrength - a.signalStrength));
    }

    // Re-filter when networks change (scan results arriving)
    Connections {
        target: root.wifiDevice?.networks ?? null
        function onValuesChanged() { root.refreshWifi(root.launcher.searchText); }
    }

    // ── WiFi processes ──
    SafeProcess {
        id: wifiConnectProc
        failMessage: "WiFi connect failed"
        onFinished: {
            wifiTracker.status = wifiTracker.status === "disconnecting" ? "disconnected" : "connected";
            wifiTracker.autoClear();
        }
        onFailed: {
            wifiTracker.status = "failed";
            if (wifiTracker.targetId !== "") {
                wifiForgetProc.command = ["nmcli", "connection", "delete", "id", wifiTracker.targetId];
                wifiForgetProc.running = true;
                root.wifiPasswordSsid = wifiTracker.targetId;
            }
            wifiTracker.autoClear();
        }
    }

    SafeProcess {
        id: wifiForgetProc
        failMessage: "WiFi forget failed"
    }


    // ── Key handler ──
    function onKeyPressed(event) {
        if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)
                && !event.isAutoRepeat) {
            Networking.wifiEnabled = !Networking.wifiEnabled;
            return true;
        }
        return false;
    }

    // ── Activate ──
    function onActivate(index) {
        if (!_validIndex(index)) return;
        const net = _sourceData[index];
        if (wifiPasswordSsid === net.name) return; // already showing password
        wifiTracker.targetId = net.name;
        if (net.connected) {
            wifiTracker.status = "disconnecting";
            wifiConnectProc.command = ["nmcli", "connection", "down", "id", net.name];
            wifiConnectProc.running = true;
        } else if (net.known || net.security === WifiSecurityType.Open) {
            wifiTracker.status = "connecting";
            wifiConnectProc.command = ["nmcli", "device", "wifi", "connect", net.name];
            wifiConnectProc.running = true;
        } else {
            wifiPasswordSsid = net.name;
        }
    }

    // Helper for password submit from delegate
    function connectWithPassword(ssid, password) {
        wifiTracker.targetId = ssid;
        wifiTracker.status = "connecting";
        wifiPasswordSsid = "";
        wifiConnectProc.command = ["sh", "-c",
            'nmcli device wifi connect "$1" password "$2" && nmcli connection modify "$1" 802-11-wireless-security.psk-flags 0',
            "sh", ssid, password];
        wifiConnectProc.running = true;
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            id: wifiStrip
            launcher: root.launcher

            readonly property bool showingPassword: root.wifiPasswordSsid === modelData.name

            // Collapsed: signal icon
            Text {
                anchors.centerIn: parent
                visible: !wifiStrip.isCurrent
                text: Theme.iconWifi
                font.family: Theme.iconFont
                font.pixelSize: Theme.launcherIconCollapsed
                color: modelData.connected ? Theme.accent : Theme.fgDim
                opacity: 0.3 + modelData.signalStrength * 0.7
            }

            // Expanded: network details
            DeviceCardBody {
                anchors.centerIn: parent
                visible: wifiStrip.isCurrent
                width: parent.width - 40

                iconText: Theme.iconWifi
                iconColor: modelData.connected ? Theme.accent : Theme.fg
                iconOpacity: Theme.opacityDim + modelData.signalStrength * Theme.opacitySubtle
                nameText: modelData.name || "Hidden Network"
                nameColor: modelData.connected ? Theme.accent : Theme.fg
                infoText: {
                    const parts = [];
                    if (UserSettings.wifiCardSignal)
                        parts.push(Math.round(modelData.signalStrength * 100) + "%");
                    if (UserSettings.wifiCardSecurity) {
                        parts.push(modelData.security === WifiSecurityType.Open
                            ? "Open"
                            : WifiSecurityType.toString(modelData.security));
                    }
                    if (UserSettings.wifiCardBand) {
                        const band = root._wifiBand(modelData.frequency);
                        if (band) parts.push(band);
                    }
                    if (UserSettings.wifiCardChannel) {
                        const ch = root._wifiChannel(modelData.frequency);
                        if (ch) parts.push("ch " + ch);
                    }
                    if (UserSettings.wifiCardBitrate && modelData.connected) {
                        const br = root.wifiDevice ? root.wifiDevice.bitrate : 0;
                        if (br > 0) parts.push((br / 1000).toFixed(0) + " Mbps");
                    }
                    if (UserSettings.wifiCardStatus && modelData.connected)
                        parts.push("Connected");
                    return parts.join(Theme.separator);
                }

                Text {
                    visible: UserSettings.wifiCardBssid && !!modelData.bssid
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.bssid || ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fgDim
                    opacity: Theme.opacityDim
                }

                StatusHintText {
                    visible: !wifiStrip.showingPassword
                    tracker: wifiTracker
                    targetId: modelData.name || ""
                    successStatuses: ["connected"]
                    neutralStatuses: ["disconnected"]
                    statusLabels: ({
                        "connecting": "Connecting...",
                        "disconnecting": "Disconnecting...",
                        "connected": "Connected",
                        "disconnected": "Disconnected",
                        "failed": "Failed — wrong password?"
                    })
                    defaultText: modelData.connected ? "Enter to disconnect" : "Enter to connect"
                }

                // Password input (inside the card)
                StyledTextField {
                    id: wifiPwField
                    visible: wifiStrip.showingPassword
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: parent.width * 0.8
                    implicitHeight: 36
                    color: Theme.overlay
                    icon: Theme.iconLock
                    echoMode: TextInput.Password
                    passwordCharacter: "\u25CF"

                    onVisibleChanged: if (visible) field.forceActiveFocus()

                    field.Keys.onReturnPressed: {
                        if (text.length > 0) {
                            root.connectWithPassword(modelData.name, text);
                            text = "";
                            root.launcher.refocusSearch();
                        }
                    }
                    field.Keys.onEscapePressed: {
                        root.wifiPasswordSsid = "";
                        root.launcher.refocusSearch();
                    }
                }
            }
        }
    }
}
