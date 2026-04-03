import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.Config
import qs.Core

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Tab config ──
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
    model: filteredWifiNetworks

    property var filteredWifiNetworks: []
    property string wifiPasswordSsid: ""  // which network is showing password input

    StatusTracker { id: wifiTracker }

    readonly property var wifiDevice: {
        const devs = Networking.devices?.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i];
        }
        return null;
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
        if (!wifiDevice || !wifiDevice.networks) { filteredWifiNetworks = []; return; }
        const nets = [];
        const values = wifiDevice.networks.values;
        const q = (searchText !== undefined ? searchText : "").toLowerCase();
        for (let i = 0; i < values.length; i++) {
            const n = values[i];
            if (q === "" || (n.name || "").toLowerCase().indexOf(q) >= 0)
                nets.push(n);
        }
        nets.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
        filteredWifiNetworks = nets;
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
        if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) {
            Networking.wifiEnabled = !Networking.wifiEnabled;
            return true;
        }
        return false;
    }

    // ── Activate ──
    function onActivate(index) {
        if (index < 0 || index >= filteredWifiNetworks.length) return;
        const net = filteredWifiNetworks[index];
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
            onActivated: root.onActivate(index)
            onSelected: root.launcher.selectedIndex = index

            readonly property bool showingPassword: root.wifiPasswordSsid === modelData.name

            // Collapsed: signal icon
            Text {
                anchors.centerIn: parent
                visible: !wifiStrip.isCurrent
                text: Theme.iconWifi
                font.family: Theme.iconFont
                font.pixelSize: 24
                color: modelData.connected ? Theme.accent : Theme.fgDim
                opacity: 0.3 + modelData.signalStrength * 0.7
            }

            // Expanded: network details
            ColumnLayout {
                anchors.centerIn: parent
                visible: wifiStrip.isCurrent
                spacing: Theme.spacingMedium
                width: parent.width - 40

                // WiFi icon — size reflects signal
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Theme.iconWifi
                    font.family: Theme.iconFont
                    font.pixelSize: 48
                    color: modelData.connected ? Theme.accent : Theme.fg
                    opacity: 0.4 + modelData.signalStrength * 0.6
                }

                // SSID
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.name || "Hidden Network"
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                    color: modelData.connected ? Theme.accent : Theme.fg
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width
                }

                // Info row: signal + security + status
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fgDim
                    text: {
                        const signal = Math.round(modelData.signalStrength * 100) + "%";
                        const sec = modelData.security === WifiSecurityType.Open ? "Open" : "Secured";
                        const status = modelData.connected ? "Connected" : "";
                        return [signal, sec, status].filter(s => s).join(Theme.separator);
                    }
                }

                // Status / action hint
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !wifiStrip.showingPassword
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    property bool isTarget: wifiTracker.targetId === modelData.name
                    color: isTarget && wifiTracker.status === "failed" ? Theme.red
                         : isTarget && wifiTracker.status === "connected" ? Theme.green
                         : isTarget && wifiTracker.status === "disconnected" ? Theme.fgDim
                         : isTarget && (wifiTracker.status === "connecting" || wifiTracker.status === "disconnecting") ? Theme.accent
                         : Theme.fgDim
                    opacity: isTarget && wifiTracker.status !== "" ? 1.0 : 0.6
                    text: {
                        if (isTarget) {
                            if (wifiTracker.status === "connecting") return "Connecting...";
                            if (wifiTracker.status === "disconnecting") return "Disconnecting...";
                            if (wifiTracker.status === "connected") return "Connected";
                            if (wifiTracker.status === "disconnected") return "Disconnected";
                            if (wifiTracker.status === "failed") return "Failed — wrong password?";
                        }
                        return modelData.connected ? "Enter to disconnect" : "Enter to connect";
                    }
                }

                // Password input (inside the card)
                Rectangle {
                    visible: wifiStrip.showingPassword
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: parent.width * 0.8
                    implicitHeight: 36
                    radius: Theme.radiusMedium
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: wifiPwInput.activeFocus ? Theme.accent : Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: Theme.spacingNormal

                        Text {
                            text: Theme.iconLock
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            color: Theme.fgDim
                            Layout.alignment: Qt.AlignVCenter
                        }

                        TextInput {
                            id: wifiPwInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            echoMode: TextInput.Password
                            passwordCharacter: "\u25CF"
                            clip: true

                            onVisibleChanged: if (visible) forceActiveFocus()

                            Keys.onReturnPressed: {
                                if (text.length > 0) {
                                    root.connectWithPassword(modelData.name, text);
                                    text = "";
                                    root.launcher.refocusSearch();
                                }
                            }
                            Keys.onEscapePressed: {
                                root.wifiPasswordSsid = "";
                                root.launcher.refocusSearch();
                            }
                        }
                    }
                }
            }
        }
    }
}
