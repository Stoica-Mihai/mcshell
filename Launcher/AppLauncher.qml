import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
    property int activeTab: 0  // 0 = Apps, 1 = Clipboard, 2 = Notifications
    property bool clipboardLoaded: false
    property var notifHistoryModel: null  // set from shell.qml
    property var filteredNotifs: []

    function switchTab(tab) {
        if (activeTab === tab) return;
        activeTab = tab;
        searchField.text = "";
        selectedIndex = 0;
        if (tab === 1 && !clipboardLoaded)
            loadClipboard();
        else
            applyFilter();
        if (tab === 2) notificationsViewed();
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

    readonly property var currentList: activeTab === 0 ? filteredApps : (activeTab === 1 ? filteredClipEntries : filteredNotifs)

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
        else applyNotifFilter();
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
                        { label: "Notifs", icon: Theme.iconBell, tab: 2 }
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
                            launcher.switchTab((launcher.activeTab + 1) % 3);
                            event.accepted = true;
                            break;
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: launcher.activeTab === 0 ? "Search apps..." : launcher.activeTab === 1 ? "Search clipboard..." : "Search notifications..."
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

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: launcher.currentList.length === 0
                text: searchField.text !== "" ? "No results" :
                      (launcher.activeTab === 1 && !launcher.clipboardLoaded ? "Loading..." : "")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fgDim
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

                    delegate: Item {
                        id: appStrip
                        required property var modelData
                        required property int index

                        readonly property bool isCurrent: index === launcher.selectedIndex
                        readonly property bool isVisible: Math.abs(index - launcher.selectedIndex) <= launcher.sideCount

                        width: isVisible ? (isCurrent ? launcher.expandedWidth : launcher.stripWidth) : 0
                        height: launcher.carouselHeight
                        clip: true
                        opacity: isVisible ? 1.0 : 0.0

                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: appStrip.isCurrent ? 14 : 8
                            color: Theme.bg
                            clip: true
                            border.width: appStrip.isCurrent ? 1 : 0
                            border.color: Theme.border

                            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                            // Collapsed: just the app icon centered
                            Image {
                                anchors.centerIn: parent
                                visible: !appStrip.isCurrent
                                width: 40
                                height: 40
                                sourceSize.width: 40
                                sourceSize.height: 40
                                source: "image://icon/" + (modelData.icon || "application-x-executable")
                                asynchronous: true
                            }

                            // Expanded: icon + name + description
                            ColumnLayout {
                                anchors.centerIn: parent
                                visible: appStrip.isCurrent
                                spacing: 12
                                width: parent.width - 40

                                Image {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 80
                                    height: 80
                                    sourceSize.width: 80
                                    sourceSize.height: 80
                                    source: "image://icon/" + (modelData.icon || "application-x-executable")
                                    asynchronous: true
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.name || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                    font.bold: true
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

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (appStrip.isCurrent)
                                    launcher.launchApp(appStrip.modelData);
                                else
                                    launcher.selectedIndex = appStrip.index;
                            }
                        }
                    }
                }

                // Clipboard carousel
                Repeater {
                    model: launcher.activeTab === 1 ? launcher.filteredClipEntries : []

                    delegate: Item {
                        id: clipStrip
                        required property var modelData
                        required property int index

                        readonly property bool isCurrent: index === launcher.selectedIndex
                        readonly property bool isVisible: Math.abs(index - launcher.selectedIndex) <= launcher.sideCount

                        width: isVisible ? (isCurrent ? launcher.expandedWidth : launcher.stripWidth) : 0
                        height: launcher.carouselHeight
                        clip: true
                        opacity: isVisible ? 1.0 : 0.0

                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: clipStrip.isCurrent ? 14 : 8
                            color: Theme.bg
                            clip: true
                            border.width: clipStrip.isCurrent ? 1 : 0
                            border.color: Theme.border

                            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                            // Collapsed icon
                            Text {
                                anchors.centerIn: parent
                                visible: !clipStrip.isCurrent
                                text: modelData.isImage ? Theme.iconImage : Theme.iconClipboard
                                font.family: Theme.iconFont
                                font.pixelSize: 24
                                color: Theme.fgDim
                            }

                            // Expanded content
                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 40
                                visible: clipStrip.isCurrent
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

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (clipStrip.isCurrent)
                                    launcher.copyClipEntry(clipStrip.modelData);
                                else
                                    launcher.selectedIndex = clipStrip.index;
                            }
                        }
                    }
                }
                // Notifications carousel
                Repeater {
                    model: launcher.activeTab === 2 ? launcher.filteredNotifs : []

                    delegate: Item {
                        id: notifStrip
                        required property var modelData
                        required property int index

                        readonly property bool isCurrent: index === launcher.selectedIndex
                        readonly property bool isVisible: Math.abs(index - launcher.selectedIndex) <= launcher.sideCount

                        width: isVisible ? (isCurrent ? launcher.expandedWidth : launcher.stripWidth) : 0
                        height: launcher.carouselHeight
                        clip: true
                        opacity: isVisible ? 1.0 : 0.0

                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: notifStrip.isCurrent ? 14 : 8
                            color: Theme.bg
                            clip: true
                            border.width: notifStrip.isCurrent ? 1 : 0
                            border.color: Theme.border

                            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                            // Collapsed: bell icon
                            Text {
                                anchors.centerIn: parent
                                visible: !notifStrip.isCurrent
                                text: Theme.iconBell
                                font.family: Theme.iconFont
                                font.pixelSize: 24
                                color: Theme.fgDim
                            }

                            // Expanded: notification details centered
                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 40
                                visible: notifStrip.isCurrent
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

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!notifStrip.isCurrent)
                                    launcher.selectedIndex = notifStrip.index;
                            }
                        }
                    }
                }
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
        visible: launcher.currentList.length > 0
        text: (launcher.selectedIndex + 1) + " / " + launcher.currentList.length
              + "  |  ← → Navigate"
              + (launcher.activeTab === 0 ? "  |  Enter launch" : launcher.activeTab === 1 ? "  |  Enter copy" : "")
              + "  |  Tab switch  |  ESC close"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fgDim
    }
}
