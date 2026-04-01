import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.Config
import qs.Core
import qs.Widgets

PanelWindow {
    id: launcher

    // ── Public API ──────────────────────────────────────
    property bool isOpen: false
    signal notificationsViewed()

    function open() {
        isOpen = true;
        visible = true;
        activeTab = 0;
        searchField.text = "";
        selectedIndex = 0;
        applyFilter();
        searchField.forceActiveFocus();
    }

    function close() {
        isOpen = false;
        visible = false;
        searchField.text = "";
        filteredApps = [];
        filteredClipEntries = [];
        filteredWifiNetworks = [];
        wifiPasswordSsid = "";
        filteredBtDevices = [];
        if (wifiDevice) wifiDevice.scannerEnabled = false;
        if (btAdapter) btAdapter.discovering = false;
    }

    function toggle() {
        if (isOpen) close(); else open();
    }

    function openTab(tab) {
        if (!isOpen) open();
        switchTab(tab);
    }

    // ── Window setup ────────────────────────────────────
    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "mcshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ── Tab state ───────────────────────────────────────
    property int activeTab: 0  // 0 = Apps, 1 = Clipboard, 2 = Notifications, 3 = WiFi, 4 = Bluetooth
    property int tabCount: 5
    property bool clipboardLoaded: false
    property var notifHistoryModel: null  // set from shell.qml
    property var filteredNotifs: []

    // ── WiFi state ─────────────────────────────────────
    property var filteredWifiNetworks: []
    property string wifiPasswordSsid: ""  // which network is showing password input
    property string wifiStatus: ""       // "" | "connecting" | "connected" | "failed"
    property string wifiStatusSsid: ""   // which network the status applies to

    readonly property var wifiDevice: {
        const devs = Networking.devices?.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i];
        }
        return null;
    }

    function refreshWifi() {
        if (!wifiDevice || !wifiDevice.networks) { filteredWifiNetworks = []; return; }
        const nets = [];
        const values = wifiDevice.networks.values;
        const q = searchField.text.toLowerCase();
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
        target: launcher.wifiDevice?.networks ?? null
        function onValuesChanged() { if (launcher.activeTab === 3) launcher.refreshWifi(); }
    }

    // ── Bluetooth state ────────────────────────────────
    property var filteredBtDevices: []
    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter?.enabled ?? false
    onBtEnabledChanged: if (!btEnabled) filteredBtDevices = []

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

    function refreshBt() {
        if (!btAdapter || !btAdapter.devices) { filteredBtDevices = []; return; }
        const devs = [];
        const values = btAdapter.devices.values;
        const q = searchField.text.toLowerCase();
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

    property string btStatus: ""         // "" | "pairing" | "connecting" | "disconnecting" | "paired" | "connected" | "failed"
    property string btStatusDevice: ""   // MAC address

    SafeProcess {
        id: btPairProc
        failMessage: "Bluetooth pairing failed"
        onRead: data => {
            const line = data.trim();
            if (line === "PAIRED" || line === "CONNECTED") {
                launcher.btStatus = line === "CONNECTED" ? "connected" : "paired";
                btStatusClear.start();
            } else if (line === "FAILED") {
                launcher.btStatus = "failed";
                btStatusClear.start();
            }
        }
        onFailed: {
            launcher.btStatus = "failed";
            btStatusClear.start();
        }
    }

    Timer {
        id: btStatusClear
        interval: 3000
        onTriggered: { launcher.btStatus = ""; launcher.btStatusDevice = ""; }
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

    // Re-filter when devices change — poll while on BT tab since
    // Connections target with optional chaining doesn't rebind
    Timer {
        interval: 2000
        running: launcher.activeTab === 4 && launcher.btEnabled
        repeat: true
        onTriggered: launcher.refreshBt()
    }

    SafeProcess {
        id: wifiConnectProc
        failMessage: "WiFi connect failed"
        onFinished: {
            launcher.wifiStatus = launcher.wifiStatus === "disconnecting" ? "disconnected" : "connected";
            wifiStatusClear.start();
        }
        onFailed: {
            launcher.wifiStatus = "failed";
            // Forget bad saved profile and show password prompt
            if (launcher.wifiStatusSsid !== "") {
                wifiForgetProc.command = ["nmcli", "connection", "delete", "id", launcher.wifiStatusSsid];
                wifiForgetProc.running = true;
                launcher.wifiPasswordSsid = launcher.wifiStatusSsid;
            }
            wifiStatusClear.start();
        }
    }

    SafeProcess {
        id: wifiForgetProc
        failMessage: "WiFi forget failed"
    }

    Timer {
        id: wifiStatusClear
        interval: 3000
        onTriggered: { launcher.wifiStatus = ""; launcher.wifiStatusSsid = ""; }
    }

    function switchTab(tab) {
        if (activeTab === tab) return;
        activeTab = tab;
        searchField.text = "";
        selectedIndex = 0;
        wifiPasswordSsid = "";
        if (tab === 1 && !clipboardLoaded)
            loadClipboard();
        else
            applyFilter();
        if (tab === 2) notificationsViewed();
        if (tab === 3 && wifiDevice) wifiDevice.scannerEnabled = true;
        if (tab === 4 && btAdapter) btAdapter.discovering = true;
        searchField.forceActiveFocus();
    }

    // ── Apps state ──────────────────────────────────────
    readonly property var allApps: {
        if (typeof DesktopEntries === "undefined") return [];
        const raw = DesktopEntries.applications.values;
        const apps = [];
        for (let i = 0; i < raw.length; i++) {
            const e = raw[i];
            if (!e || e.noDisplay) continue;
            apps.push(e);
        }
        apps.sort((a, b) => (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase()));
        return apps;
    }
    property var filteredApps: []
    property int selectedIndex: 0

    // ── Carousel config ─────────────────────────────────
    readonly property int sideCount: 5
    readonly property real stripWidth: 80
    readonly property real expandedWidth: 500
    readonly property real carouselHeight: 350
    readonly property real stripSpacing: 6

    readonly property var currentList: activeTab === 0 ? filteredApps
        : activeTab === 1 ? filteredClipEntries
        : activeTab === 2 ? filteredNotifs
        : activeTab === 3 ? filteredWifiNetworks
        : filteredBtDevices

    function navigate(delta) {
        if (currentList.length === 0) return;
        selectedIndex = Math.max(0, Math.min(currentList.length - 1, selectedIndex + delta));
    }

    function calcRowX() {
        if (currentList.length === 0) return carouselArea.width / 2;
        const firstVisible = Math.max(0, selectedIndex - sideCount);
        const visibleLeftCount = selectedIndex - firstVisible;
        const leftWidth = visibleLeftCount * (stripWidth + stripSpacing);
        const centerOffset = expandedWidth / 2;
        const collapsedCount = firstVisible;
        const collapsedWidth = collapsedCount * stripSpacing;
        return carouselArea.width / 2 - collapsedWidth - leftWidth - centerOffset;
    }

    // ── Launch/activate ─────────────────────────────────
    function launchApp(entry) {
        close();
        Qt.callLater(function() { if (entry) entry.execute(); });
    }

    function activate() {
        if (selectedIndex < 0 || selectedIndex >= currentList.length) return;
        if (activeTab === 0)
            launchApp(filteredApps[selectedIndex]);
        else if (activeTab === 1)
            copyClipEntry(filteredClipEntries[selectedIndex]);
        // Notifications: Enter does nothing (view only)
        else if (activeTab === 3) {
            const net = filteredWifiNetworks[selectedIndex];
            if (wifiPasswordSsid === net.name) return; // already showing password
            wifiStatusSsid = net.name;
            if (net.connected) {
                wifiStatus = "disconnecting";
                wifiConnectProc.command = ["nmcli", "connection", "down", "id", net.name];
                wifiConnectProc.running = true;
            } else if (net.known || net.security === WifiSecurityType.Open) {
                wifiStatus = "connecting";
                wifiConnectProc.command = ["nmcli", "device", "wifi", "connect", net.name];
                wifiConnectProc.running = true;
            } else {
                wifiPasswordSsid = net.name;
            }
        } else if (activeTab === 4) {
            const dev = filteredBtDevices[selectedIndex];
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
    }

    // ── Clipboard helpers ───────────────────────────────
    property var allClipEntries: []
    property var filteredClipEntries: []

    function loadClipboard() {
        clipHistLines = [];
        clipHistProc.running = true;
    }

    property var clipHistLines: []

    SafeProcess {
        id: clipHistProc
        command: ["cliphist", "list"]
        failMessage: "cliphist not found — clipboard history unavailable"
        onRead: data => { launcher.clipHistLines = launcher.clipHistLines.concat([data]); }
        onFinished: {
            launcher.allClipEntries = parseClipEntries(launcher.clipHistLines);
            launcher.clipboardLoaded = true;
            launcher.applyFilter();
        }
        onFailed: {
            launcher.clipboardLoaded = true;
            launcher.applyFilter();
        }
    }

    function parseClipEntries(lines) {
        const imagePattern = /^\[\[\s*binary data\s+.+\s+(png|jpe?g|webp|bmp)\s+\d+x\d+\s*\]\]$/i;
        const entries = [];
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const tabIdx = line.indexOf("\t");
            if (tabIdx < 0) continue;
            const id = line.substring(0, tabIdx).trim();
            const content = line.substring(tabIdx + 1).trim();
            if (id === "" || content === "") continue;
            const isImage = imagePattern.test(content);
            entries.push({ id: id, content: content, raw: line, isImage: isImage });
        }
        return entries;
    }


    property string clipSelectRaw: ""
    SafeProcess {
        id: clipCopyProc
        command: ["bash", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "bash", launcher.clipSelectRaw]
        failMessage: "clipboard paste failed"
    }

    function copyClipEntry(entry) {
        clipSelectRaw = entry.raw;
        clipCopyProc.running = true;
        close();
    }

    // ── Fuzzy filter ────────────────────────────────────
    function applyFilter() {
        if (activeTab === 0) applyAppFilter();
        else if (activeTab === 1) applyClipFilter();
        else if (activeTab === 2) applyNotifFilter();
        else if (activeTab === 3) refreshWifi();
        else if (activeTab === 4) refreshBt();
    }

    function applyNotifFilter() {
        if (!notifHistoryModel) { filteredNotifs = []; selectedIndex = 0; return; }
        const query = searchField.text.toLowerCase().trim();
        const results = [];
        for (let i = 0; i < notifHistoryModel.count; i++) {
            const item = notifHistoryModel.get(i);
            // Copy to plain JS object — ListModel references become invalid after model changes
            const copy = {
                notifId: item.notifId || "",
                appName: item.appName || "",
                summary: item.summary || "",
                body: item.body || "",
                iconUrl: item.iconUrl || "",
                urgency: item.urgency || 0,
                timestamp: item.timestamp || ""
            };
            if (query === "" || copy.summary.toLowerCase().indexOf(query) >= 0
                || copy.body.toLowerCase().indexOf(query) >= 0
                || copy.appName.toLowerCase().indexOf(query) >= 0) {
                results.push(copy);
            }
        }
        filteredNotifs = results;
        selectedIndex = 0;
    }

    function applyAppFilter() {
        const query = searchField.text.toLowerCase().trim();
        if (query === "") { filteredApps = allApps; selectedIndex = 0; return; }
        const scored = [];
        for (let i = 0; i < allApps.length; i++) {
            const app = allApps[i];
            let score = fuzzyScore(query, (app.name || "").toLowerCase());
            if (score < 0) {
                const alt = fuzzyScore(query, (app.comment || app.genericName || "").toLowerCase());
                if (alt >= 0) score = alt - 10;
            }
            if (score >= 0) scored.push({ app: app, score: score });
        }
        scored.sort((a, b) => b.score - a.score);
        filteredApps = scored.map(s => s.app);
        selectedIndex = 0;
    }

    function applyClipFilter() {
        const query = searchField.text.toLowerCase().trim();
        if (query === "") { filteredClipEntries = allClipEntries; selectedIndex = 0; return; }
        const results = [];
        for (let i = 0; i < allClipEntries.length; i++) {
            if (allClipEntries[i].content.toLowerCase().indexOf(query) >= 0)
                results.push(allClipEntries[i]);
        }
        filteredClipEntries = results;
        selectedIndex = 0;
    }

    function fuzzyScore(query, target) {
        if (target.indexOf(query) >= 0) {
            if (target.indexOf(query) === 0) return 200;
            return 150;
        }
        var qi = 0, lastMatchIdx = -1, score = 100;
        for (var ti = 0; ti < target.length && qi < query.length; ti++) {
            if (target[ti] === query[qi]) {
                if (lastMatchIdx >= 0 && ti === lastMatchIdx + 1) score += 5;
                if (ti === 0 || target[ti - 1] === " " || target[ti - 1] === "-") score += 3;
                lastMatchIdx = ti;
                qi++;
            }
        }
        if (qi < query.length) return -1;
        score -= (lastMatchIdx - (lastMatchIdx - qi + 1));
        return score;
    }

    // ── UI ──────────────────────────────────────────────

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: launcher.close() }
    }

    // Search bar — fixed position above center
    Rectangle {
        id: searchBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: carouselArea.top
        anchors.bottomMargin: 20
        width: Math.min(600, parent.width - 160)
        height: 44
            radius: 10
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                // Tab buttons
                Repeater {
                    model: [
                        { label: "Apps", icon: Theme.iconApps, tab: 0 },
                        { label: "Clip", icon: Theme.iconClipboard, tab: 1 },
                        { label: "Notifs", icon: Theme.iconBell, tab: 2 },
                        { label: "WiFi", icon: Networking.wifiEnabled ? Theme.iconWifi : Theme.iconWifiOff, tab: 3 },
                        { label: "BT", icon: Theme.iconBluetooth, tab: 4 }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 28
                        radius: 6
                        color: launcher.activeTab === modelData.tab ? Theme.accent : "transparent"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: modelData.icon
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: launcher.activeTab === modelData.tab ? Theme.bgSolid : Theme.fgDim
                            }

                            Text {
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: launcher.activeTab === modelData.tab ? Theme.bgSolid : Theme.fgDim
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.switchTab(modelData.tab)
                        }
                    }
                }

                // Separator
                Rectangle { width: 1; Layout.preferredHeight: 20; color: Theme.border }

                // Search icon
                Text {
                    text: Theme.iconSearch
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: Theme.fgDim
                    Layout.alignment: Qt.AlignVCenter
                }

                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                    clip: true
                    selectByMouse: true

                    onTextChanged: launcher.applyFilter()

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape: launcher.close(); event.accepted = true; break;
                        case Qt.Key_Left: launcher.navigate(-1); event.accepted = true; break;
                        case Qt.Key_Right: launcher.navigate(1); event.accepted = true; break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter: launcher.activate(); event.accepted = true; break;
                        case Qt.Key_Tab:
                            launcher.switchTab((launcher.activeTab + 1) % launcher.tabCount);
                            event.accepted = true;
                            break;
                        case Qt.Key_W:
                            if (launcher.activeTab === 3 && (event.modifiers & Qt.ControlModifier)) {
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                                event.accepted = true;
                            }
                            break;
                        case Qt.Key_B:
                            if (launcher.activeTab === 4 && (event.modifiers & Qt.ControlModifier) && launcher.btAdapter) {
                                launcher.btAdapter.enabled = !launcher.btAdapter.enabled;
                                event.accepted = true;
                            }
                            break;
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: launcher.activeTab === 0 ? "Search apps..."
                            : launcher.activeTab === 1 ? "Search clipboard..."
                            : launcher.activeTab === 2 ? "Search notifications..."
                            : launcher.activeTab === 3 ? "Search networks..."
                            : "Search devices..."
                        color: Theme.fgDim
                        font: parent.font
                        visible: !parent.text
                    }
                }
            }
        }

    // Carousel — centered on screen, fixed position
    Item {
            id: carouselArea
            anchors.centerIn: parent
            width: parent.width
            height: launcher.carouselHeight
            clip: true

            // Empty state — text for search/generic
            Text {
                anchors.centerIn: parent
                visible: launcher.currentList.length === 0
                      && searchField.text !== ""
                text: "No results"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fgDim
            }

            // Loading state — clipboard
            Text {
                anchors.centerIn: parent
                visible: launcher.activeTab === 1 && !launcher.clipboardLoaded && searchField.text === ""
                text: "Loading..."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fgDim
            }

            // Scanning state — WiFi
            DisabledCard {
                visible: launcher.activeTab === 3 && Networking.wifiEnabled
                      && launcher.filteredWifiNetworks.length === 0 && searchField.text === ""
                anchors.centerIn: parent
                width: launcher.expandedWidth
                height: launcher.carouselHeight
                icon: Theme.iconWifi
                iconColor: Theme.accent
                iconOpacity: 0.3
                hint: "Scanning for networks..."
            }

            // Scanning state — Bluetooth
            DisabledCard {
                visible: launcher.activeTab === 4 && launcher.btEnabled
                      && launcher.filteredBtDevices.length === 0 && searchField.text === ""
                anchors.centerIn: parent
                width: launcher.expandedWidth
                height: launcher.carouselHeight
                icon: Theme.iconBluetooth
                iconColor: Theme.accent
                iconOpacity: 0.3
                hint: "Scanning for devices..."
            }

            // WiFi off — single card
            DisabledCard {
                visible: launcher.activeTab === 3 && !Networking.wifiEnabled
                anchors.centerIn: parent
                width: launcher.expandedWidth
                height: launcher.carouselHeight
                icon: Theme.iconWifiOff
                hint: "Ctrl+W to enable"
            }

            // Sliding row
            Row {
                id: slidingRow
                x: launcher.calcRowX()
                height: launcher.carouselHeight
                spacing: launcher.stripSpacing
                visible: launcher.currentList.length > 0

                Behavior on x {
                    NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                }

                // Apps carousel
                Repeater {
                    model: launcher.activeTab === 0 ? launcher.filteredApps : []

                    delegate: CarouselStrip {
                        selectedIndex: launcher.selectedIndex
                        sideCount: launcher.sideCount
                        expandedWidth: launcher.expandedWidth
                        stripWidth: launcher.stripWidth
                        carouselHeight: launcher.carouselHeight
                        onActivated: launcher.launchApp(modelData)
                        onSelected: launcher.selectedIndex = index

                        // Collapsed
                        Image {
                            anchors.centerIn: parent
                            visible: !parent.isCurrent
                            width: 40; height: 40
                            sourceSize.width: 40; sourceSize.height: 40
                            source: "image://icon/" + (modelData.icon || "application-x-executable")
                            asynchronous: true
                        }

                        // Expanded
                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: parent.isCurrent
                            spacing: 12
                            width: parent.width - 40

                            Image {
                                Layout.alignment: Qt.AlignHCenter
                                width: 80; height: 80
                                sourceSize.width: 80; sourceSize.height: 80
                                source: "image://icon/" + (modelData.icon || "application-x-executable")
                                asynchronous: true
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.name || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 18; font.bold: true
                                color: Theme.fg
                                elide: Text.ElideRight
                                Layout.maximumWidth: parent.width
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.comment || modelData.genericName || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.fgDim
                                elide: Text.ElideRight
                                visible: text !== ""
                                Layout.maximumWidth: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                maximumLineCount: 2
                            }
                        }
                    }
                }

                // Clipboard carousel
                Repeater {
                    model: launcher.activeTab === 1 ? launcher.filteredClipEntries : []

                    delegate: CarouselStrip {
                        selectedIndex: launcher.selectedIndex
                        sideCount: launcher.sideCount
                        expandedWidth: launcher.expandedWidth
                        stripWidth: launcher.stripWidth
                        carouselHeight: launcher.carouselHeight
                        onActivated: launcher.copyClipEntry(modelData)
                        onSelected: launcher.selectedIndex = index

                        // Collapsed icon
                        Text {
                            anchors.centerIn: parent
                            visible: !parent.isCurrent
                            text: modelData.isImage ? Theme.iconImage : Theme.iconClipboard
                            font.family: Theme.iconFont
                            font.pixelSize: 24
                            color: Theme.fgDim
                        }

                        // Expanded content
                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 40
                            visible: parent.isCurrent
                            spacing: 10

                            Text {
                                text: modelData.isImage ? Theme.iconImage : Theme.iconClipboard
                                font.family: Theme.iconFont
                                font.pixelSize: 32
                                color: Theme.accent
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.isImage ? "Image" : (modelData.content || "")
                                textFormat: Text.PlainText
                                font.family: Theme.fontFamily
                                font.pixelSize: modelData.isImage ? 18 : Theme.fontSizeSmall
                                font.bold: modelData.isImage
                                color: Theme.fg
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                elide: Text.ElideRight
                                maximumLineCount: modelData.isImage ? 1 : 12
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // Show image metadata for image entries
                            Text {
                                visible: modelData.isImage
                                Layout.fillWidth: true
                                text: {
                                    // Extract size and dimensions from "[[ binary data 154 KiB png 1223x521 ]]"
                                    const m = (modelData.content || "").match(/(\d+\s*\w+)\s+(png|jpe?g|webp|bmp)\s+(\d+x\d+)/i);
                                    if (m) return m[3] + "  •  " + m[2].toUpperCase() + "  •  " + m[1];
                                    return modelData.content || "";
                                }
                                textFormat: Text.PlainText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.fgDim
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
                // Notifications carousel
                Repeater {
                    model: launcher.activeTab === 2 ? launcher.filteredNotifs : []

                    delegate: CarouselStrip {
                        selectedIndex: launcher.selectedIndex
                        sideCount: launcher.sideCount
                        expandedWidth: launcher.expandedWidth
                        stripWidth: launcher.stripWidth
                        carouselHeight: launcher.carouselHeight
                        onSelected: launcher.selectedIndex = index

                        // Collapsed: bell icon
                        Text {
                            anchors.centerIn: parent
                            visible: !parent.isCurrent
                            text: Theme.iconBell
                            font.family: Theme.iconFont
                            font.pixelSize: 24
                            color: Theme.fgDim
                        }

                        // Expanded: notification details centered
                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 40
                            visible: parent.isCurrent
                            spacing: 8

                            // Image preview if available
                            Rectangle {
                                id: notifPreviewContainer
                                visible: notifPreviewImg.status === Image.Ready
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: Math.min(parent.width, 300)
                                Layout.preferredHeight: visible ? Layout.preferredWidth * 9 / 16 : 0
                                radius: 8
                                color: Theme.bgSolid
                                clip: true

                                Image {
                                    id: notifPreviewImg
                                    anchors.fill: parent
                                    source: {
                                        const url = modelData.iconUrl || "";
                                        // Only load direct file paths — avoid image://icon/ provider
                                        // which can crash with large screenshots
                                        if (url.startsWith("file://"))
                                            return url;
                                        if (url.startsWith("/"))
                                            return "file://" + url;
                                        return "";
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            // App name + timestamp
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8

                                Text {
                                    text: modelData.appName || "Notification"
                                    textFormat: Text.PlainText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    color: Theme.fgDim
                                }

                                Text {
                                    text: modelData.timestamp || ""
                                    textFormat: Text.PlainText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    color: Theme.fgDim
                                    visible: text !== ""
                                }
                            }

                            // Summary
                            Text {
                                Layout.fillWidth: true
                                text: modelData.summary || ""
                                textFormat: Text.PlainText
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.bold: true
                                color: Theme.fg
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            // Body
                            Text {
                                Layout.fillWidth: true
                                text: modelData.body || ""
                                textFormat: Text.PlainText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.fg
                                opacity: 0.85
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                maximumLineCount: 6
                                elide: Text.ElideRight
                                visible: text !== ""
                            }
                        }
                    }
                }

                // WiFi carousel
                Repeater {
                    model: launcher.activeTab === 3 ? launcher.filteredWifiNetworks : []

                    delegate: CarouselStrip {
                        id: wifiStrip
                        selectedIndex: launcher.selectedIndex
                        sideCount: launcher.sideCount
                        expandedWidth: launcher.expandedWidth
                        stripWidth: launcher.stripWidth
                        carouselHeight: launcher.carouselHeight
                        borderColor: modelData.connected ? Theme.accent : Theme.border
                        onActivated: launcher.activate()
                        onSelected: launcher.selectedIndex = index

                        readonly property bool showingPassword: launcher.wifiPasswordSsid === modelData.name

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
                            spacing: 10
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
                                    return [signal, sec, status].filter(s => s).join("  •  ");
                                }
                            }

                            // Status / action hint
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                visible: !wifiStrip.showingPassword
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                property bool isTarget: launcher.wifiStatusSsid === modelData.name
                                color: isTarget && launcher.wifiStatus === "failed" ? Theme.red
                                     : isTarget && launcher.wifiStatus === "connected" ? Theme.green
                                     : isTarget && launcher.wifiStatus === "disconnected" ? Theme.fgDim
                                     : isTarget && (launcher.wifiStatus === "connecting" || launcher.wifiStatus === "disconnecting") ? Theme.accent
                                     : Theme.fgDim
                                opacity: isTarget && launcher.wifiStatus !== "" ? 1.0 : 0.6
                                text: {
                                    if (isTarget) {
                                        if (launcher.wifiStatus === "connecting") return "Connecting...";
                                        if (launcher.wifiStatus === "disconnecting") return "Disconnecting...";
                                        if (launcher.wifiStatus === "connected") return "Connected";
                                        if (launcher.wifiStatus === "disconnected") return "Disconnected";
                                        if (launcher.wifiStatus === "failed") return "Failed — wrong password?";
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
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.width: 1
                                border.color: wifiPwInput.activeFocus ? Theme.accent : Theme.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

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
                                        passwordCharacter: "●"
                                        clip: true

                                        onVisibleChanged: if (visible) forceActiveFocus()

                                        Keys.onReturnPressed: {
                                            if (text.length > 0) {
                                                const ssid = modelData.name;
                                                const pw = text;
                                                launcher.wifiStatusSsid = ssid;
                                                launcher.wifiStatus = "connecting";
                                                launcher.wifiPasswordSsid = "";
                                                // Connect and store password in system config (no agent needed)
                                                wifiConnectProc.command = ["sh", "-c",
                                                    'nmcli device wifi connect "$1" password "$2" && nmcli connection modify "$1" 802-11-wireless-security.psk-flags 0',
                                                    "sh", ssid, pw];
                                                wifiConnectProc.running = true;
                                                text = "";
                                                searchField.forceActiveFocus();
                                            }
                                        }
                                        Keys.onEscapePressed: {
                                            launcher.wifiPasswordSsid = "";
                                            searchField.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // Bluetooth carousel
                Repeater {
                    model: launcher.activeTab === 4 && launcher.btEnabled ? launcher.filteredBtDevices : []

                    delegate: CarouselStrip {
                        selectedIndex: launcher.selectedIndex
                        sideCount: launcher.sideCount
                        expandedWidth: launcher.expandedWidth
                        stripWidth: launcher.stripWidth
                        carouselHeight: launcher.carouselHeight
                        borderColor: modelData.connected ? Theme.accent : Theme.border
                        onActivated: launcher.activate()
                        onSelected: launcher.selectedIndex = index

                        // Collapsed: device type icon
                        Text {
                            anchors.centerIn: parent
                            visible: !parent.isCurrent
                            text: launcher.btDeviceIcon(modelData.icon)
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
                                text: launcher.btDeviceIcon(modelData.icon)
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
                                property bool isTarget: launcher.btStatusDevice === modelData.address
                                color: isTarget && launcher.btStatus === "failed" ? Theme.red
                                     : isTarget && (launcher.btStatus === "connected" || launcher.btStatus === "paired") ? Theme.green
                                     : isTarget && launcher.btStatus !== "" ? Theme.accent
                                     : Theme.fgDim
                                opacity: isTarget && launcher.btStatus !== "" ? 1.0 : 0.6
                                text: {
                                    if (isTarget) {
                                        if (launcher.btStatus === "pairing") return "Pairing...";
                                        if (launcher.btStatus === "connecting") return "Connecting...";
                                        if (launcher.btStatus === "disconnecting") return "Disconnecting...";
                                        if (launcher.btStatus === "connected") return "Connected";
                                        if (launcher.btStatus === "paired") return "Paired";
                                        if (launcher.btStatus === "failed") return "Failed";
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

            // Bluetooth off — single card
            DisabledCard {
                visible: launcher.activeTab === 4 && !launcher.btEnabled
                anchors.centerIn: parent
                width: launcher.expandedWidth
                height: launcher.carouselHeight
                icon: Theme.iconBluetooth
                hint: "Ctrl+B to enable"
            }

            // Navigation arrows
            IconButton {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                icon: Theme.iconArrowLeft
                size: 24
                normalColor: Theme.fgDim
                visible: launcher.selectedIndex > 0 && launcher.currentList.length > 0
                onClicked: launcher.navigate(-1)
            }

            IconButton {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                icon: Theme.iconArrowRight
                size: 24
                normalColor: Theme.fgDim
                visible: launcher.selectedIndex < launcher.currentList.length - 1 && launcher.currentList.length > 0
                onClicked: launcher.navigate(1)
            }
        }

    // Footer — fixed position below carousel
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: carouselArea.bottom
        anchors.topMargin: 16
        visible: launcher.currentList.length > 0 || launcher.activeTab === 3 || launcher.activeTab === 4
        text: {
            // WiFi/BT off states
            if (launcher.activeTab === 3 && !Networking.wifiEnabled)
                return "Ctrl+W toggle WiFi  |  Tab switch  |  ESC close";
            if (launcher.activeTab === 4 && !launcher.btEnabled)
                return "Ctrl+B toggle Bluetooth  |  Tab switch  |  ESC close";

            var t = (launcher.selectedIndex + 1) + " / " + launcher.currentList.length
                  + "  |  ← → Navigate";
            if (launcher.activeTab === 0) t += "  |  Enter launch";
            else if (launcher.activeTab === 1) t += "  |  Enter copy";
            else if (launcher.activeTab === 3) t += "  |  Enter connect  |  Ctrl+W toggle WiFi";
            else if (launcher.activeTab === 4) t += "  |  Enter connect  |  Ctrl+B toggle Bluetooth";
            t += "  |  Tab switch  |  ESC close";
            return t;
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fgDim
    }
}
