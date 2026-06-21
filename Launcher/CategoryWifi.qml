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
    // Single-source the toggle key so the handler (Ctrl+W) and its labels can't drift.
    readonly property string _toggleKey: "Ctrl+W"
    readonly property string _toggleHint: _toggleKey + " toggle WiFi"
    legendHint: Theme.legend(Theme.hintEnter + " connect", _toggleHint)
    disabledLegendHint: _toggleHint

    // ── Disabled state ──
    disabledState: !Networking.wifiEnabled
    disabledIcon: Theme.iconWifiOff
    disabledHint: _toggleKey + " to enable"

    // ── Scanning state ──
    scanningState: Networking.wifiEnabled
    scanningIcon: Theme.iconWifi
    scanningHint: "Scanning for networks..."

    // ── Data ──
    property string wifiPasswordSsid: ""  // which network is showing password input

    StatusTracker { id: wifiTracker }

    readonly property var wifiDevice: NetworkInfo.wifiDevice

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

    // Track the network we last asked to connect, so we know what to
    // forget on a NoSecrets/WrongSecrets failure.
    property var _activeNet: null
    Connections {
        target: _activeNet
        function onConnectedChanged() {
            if (!_activeNet) return;
            if (_activeNet.connected) {
                wifiTracker.set(ConnStatus.connected);
            } else if (wifiTracker.status === ConnStatus.disconnecting) {
                // The complementary path — flip from "disconnecting" → "disconnected"
                // when the device actually drops the connection. Without this the
                // status sticks at "disconnecting..." forever.
                wifiTracker.set(ConnStatus.disconnected);
            }
        }
        function onConnectionFailed(reason) {
            wifiTracker.set(ConnStatus.failed);
            // If the network was just-added with a wrong PSK, forget it so
            // the next connect attempt prompts again instead of silently
            // re-trying with the bad credentials. (Reason values 1=NoSecrets,
            // 2=WrongSecrets per Quickshell.Networking.ConnectionFailReason.)
            if ((reason === 1 || reason === 2) && _activeNet) {
                _activeNet.forget();
                root.wifiPasswordSsid = wifiTracker.targetId;
            }
        }
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
        _activeNet = net;
        if (net.connected) {
            wifiTracker.status = ConnStatus.disconnecting;
            net.disconnect();
        } else if (net.known || net.security === WifiSecurityType.Open) {
            wifiTracker.status = ConnStatus.connecting;
            net.connect();
        } else {
            wifiPasswordSsid = net.name;
        }
    }

    // Helper for password submit from delegate
    function connectWithPassword(net, password) {
        if (!net) return;
        wifiTracker.targetId = net.name;
        wifiTracker.status = ConnStatus.connecting;
        wifiPasswordSsid = "";
        _activeNet = net;
        net.connectWithPsk(password);
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            id: wifiStrip
            launcher: root.launcher

            readonly property bool showingPassword: root.wifiPasswordSsid === modelData.name

            // Collapsed: signal icon
            CollapsedCardIcon {
                visible: !wifiStrip.isCurrent
                text: Theme.iconWifi
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
                        parts.push(Theme.percent(modelData.signalStrength) + "%");
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
                SkewTextField {
                    id: wifiPwField
                    visible: wifiStrip.showingPassword
                    Layout.alignment: Qt.AlignHCenter
                    // Card body is narrow — escape the parent's preferredWidth
                    // so the field gets actual typing room. Carousel strip
                    // around the card is wide enough to host this comfortably.
                    Layout.preferredWidth: 320
                    Layout.minimumWidth: 320
                    Layout.preferredHeight: 44
                    placeholder: "Password"
                    icon: Theme.iconLock
                    iconSize: 14
                    echoMode: TextInput.Password
                    passwordCharacter: "\u25CF"
                    showVisibilityToggle: true

                    onVisibleChanged: if (visible) field.forceActiveFocus()

                    field.Keys.onReturnPressed: {
                        if (text.length > 0) {
                            root.connectWithPassword(modelData, text);
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
