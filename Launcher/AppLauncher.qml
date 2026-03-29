import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Config

PanelWindow {
    id: launcher

    // ── Public API ──────────────────────────────────────
    property bool isOpen: false

    function open() {
        isOpen = true;
        visible = true;
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

    // ── Window setup ────────────────────────────────────
    visible: false
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "mcshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ── Tab state ─────────────────────────────────────────
    property int activeTab: 0          // 0 = Apps, 1 = Clipboard
    property bool clipboardLoaded: false

    function switchTab(tab) {
        if (activeTab === tab) return;
        activeTab = tab;
        searchField.text = "";
        selectedIndex = 0;
        if (tab === 1 && !clipboardLoaded) {
            loadClipboard();
        } else {
            applyFilter();
        }
        searchField.forceActiveFocus();
    }

    // ── Apps state ────────────────────────────────────────
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
    property int maxVisible: 10

    // ── Clipboard state ───────────────────────────────────
    property var allClipEntries: []
    property var filteredClipEntries: []

    // ── Launch helper ───────────────────────────────────
    function launchApp(entry) {
        close();
        Qt.callLater(function() {
            if (entry) entry.execute();
        });
    }

    // ── Clipboard helpers ─────────────────────────────────
    function loadClipboard() {
        clipHistLines = [];
        clipHistProc.running = true;
    }

    property var clipHistLines: []

    Process {
        id: clipHistProc
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: data => {
                launcher.clipHistLines = launcher.clipHistLines.concat([data]);
            }
        }
        onExited: (exitCode, exitStatus) => {
            launcher.allClipEntries = parseClipEntries(launcher.clipHistLines);
            launcher.clipboardLoaded = true;
            launcher.applyFilter();
        }
    }

    function parseClipEntries(lines) {
        const entries = [];
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            // cliphist format: "<id>\t<content>"
            const tabIdx = line.indexOf("\t");
            if (tabIdx < 0) continue;
            const id = line.substring(0, tabIdx).trim();
            const content = line.substring(tabIdx + 1).trim();
            if (id === "" || content === "") continue;
            entries.push({ id: id, content: content, raw: line });
        }
        return entries;
    }

    property string clipSelectRaw: ""

    Process {
        id: clipCopyProc
        command: ["bash", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "bash", launcher.clipSelectRaw]
    }

    function copyClipEntry(entry) {
        clipSelectRaw = entry.raw;
        clipCopyProc.running = true;
        close();
    }

    property string clipDeleteRaw: ""

    Process {
        id: clipDeleteProc
        command: ["bash", "-c", "printf '%s' \"$1\" | cliphist delete", "bash", launcher.clipDeleteRaw]
        onExited: {
            // Remove from local arrays and refresh
            const remaining = [];
            for (let i = 0; i < launcher.allClipEntries.length; i++) {
                if (launcher.allClipEntries[i].raw !== launcher.clipDeleteRaw)
                    remaining.push(launcher.allClipEntries[i]);
            }
            launcher.allClipEntries = remaining;
            launcher.applyFilter();
        }
    }

    function deleteClipEntry(entry) {
        clipDeleteRaw = entry.raw;
        clipDeleteProc.running = true;
    }

    // ── Fuzzy filter ────────────────────────────────────
    function applyFilter() {
        if (activeTab === 0) {
            applyAppFilter();
        } else {
            applyClipFilter();
        }
    }

    function applyAppFilter() {
        const query = searchField.text.toLowerCase().trim();
        if (query === "") {
            filteredApps = allApps;
            selectedIndex = 0;
            return;
        }
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
        if (query === "") {
            filteredClipEntries = allClipEntries;
            selectedIndex = 0;
            return;
        }
        const results = [];
        for (let i = 0; i < allClipEntries.length; i++) {
            const entry = allClipEntries[i];
            if (entry.content.toLowerCase().indexOf(query) >= 0) {
                results.push(entry);
            }
        }
        filteredClipEntries = results;
        selectedIndex = 0;
    }

    // Simple fuzzy scorer: returns >= 0 if all chars of query appear in
    // order within target. Higher score = tighter match.
    function fuzzyScore(query, target) {
        if (target.indexOf(query) >= 0) {
            // Substring match -- strong bonus. Starts-with is best.
            if (target.indexOf(query) === 0) return 200;
            return 150;
        }
        var qi = 0;
        var lastMatchIdx = -1;
        var score = 100;
        for (var ti = 0; ti < target.length && qi < query.length; ti++) {
            if (target[ti] === query[qi]) {
                // Bonus for consecutive chars
                if (lastMatchIdx >= 0 && ti === lastMatchIdx + 1) score += 5;
                // Bonus for matching at word boundary
                if (ti === 0 || target[ti - 1] === " " || target[ti - 1] === "-") score += 3;
                lastMatchIdx = ti;
                qi++;
            }
        }
        if (qi < query.length) return -1; // not all chars matched
        // Penalise by spread
        score -= (lastMatchIdx - (lastMatchIdx - qi + 1));
        return score;
    }

    // ── Keyboard navigation ─────────────────────────────
    readonly property var currentList: activeTab === 0 ? filteredApps : filteredClipEntries

    function moveUp() {
        if (selectedIndex > 0) selectedIndex--;
    }
    function moveDown() {
        if (selectedIndex < currentList.length - 1) selectedIndex++;
    }
    function activate() {
        if (selectedIndex < 0 || selectedIndex >= currentList.length) return;
        if (activeTab === 0) {
            launchApp(filteredApps[selectedIndex]);
        } else {
            copyClipEntry(filteredClipEntries[selectedIndex]);
        }
    }

    // ── UI ──────────────────────────────────────────────

    // Semi-transparent dimmer -- click to close
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.close()
        }
    }

    // Centered panel
    Rectangle {
        id: panel
        width: 520
        height: Math.min(panelColumn.implicitHeight + 32, parent.height * 0.7)
        anchors.centerIn: parent
        radius: 12
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        clip: true

        ColumnLayout {
            id: panelColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Tab bar ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: [
                        { label: "Apps",      icon: Theme.iconApps,      tab: 0 },
                        { label: "Clipboard", icon: Theme.iconClipboard, tab: 1 }
                    ]

                    delegate: Item {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: tabCol.implicitHeight + 8

                        readonly property bool active: launcher.activeTab === modelData.tab

                        ColumnLayout {
                            id: tabCol
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 6

                                Text {
                                    text: modelData.icon
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.fontSize
                                    color: active ? Theme.accent : Theme.fgDim

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.weight: active ? Font.Medium : Font.Normal
                                    color: active ? Theme.accent : Theme.fgDim

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            // Accent underline
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: parent.width
                                Layout.preferredHeight: 2
                                radius: 1
                                color: active ? Theme.accent : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.switchTab(modelData.tab)
                        }
                    }
                }
            }

            // ── Separator below tabs ──────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // Search field
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 8
                color: Theme.bgSolid
                border.width: 1
                border.color: searchField.activeFocus ? Theme.accent : Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    // Search icon (using image://icon for theme icon)
                    Image {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        sourceSize.width: 16
                        sourceSize.height: 16
                        source: "image://icon/edit-find"
                        opacity: 0.5
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
                            case Qt.Key_Escape:
                                launcher.close();
                                event.accepted = true;
                                break;
                            case Qt.Key_Up:
                                launcher.moveUp();
                                event.accepted = true;
                                break;
                            case Qt.Key_Down:
                                launcher.moveDown();
                                event.accepted = true;
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                launcher.activate();
                                event.accepted = true;
                                break;
                            case Qt.Key_Tab:
                                if (event.modifiers & Qt.ControlModifier) {
                                    launcher.switchTab(launcher.activeTab === 0 ? 1 : 0);
                                } else {
                                    launcher.moveDown();
                                }
                                event.accepted = true;
                                break;
                            case Qt.Key_Backtab:
                                if (event.modifiers & Qt.ControlModifier) {
                                    launcher.switchTab(launcher.activeTab === 0 ? 1 : 0);
                                } else {
                                    launcher.moveUp();
                                }
                                event.accepted = true;
                                break;
                            }
                        }

                        // Placeholder
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: launcher.activeTab === 0
                                  ? "Search applications..."
                                  : "Search clipboard..."
                            color: Theme.fgDim
                            font: parent.font
                            visible: !parent.text
                        }
                    }
                }
            }

            // ── Apps results list ─────────────────────────
            ListView {
                id: resultsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(filteredApps.length, launcher.maxVisible) * 44
                clip: true
                model: filteredApps
                currentIndex: launcher.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 80
                visible: launcher.activeTab === 0

                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }
                }

                delegate: Rectangle {
                    id: delegateItem
                    required property var modelData
                    required property int index

                    width: resultsList.width
                    height: 44
                    radius: 6
                    color: {
                        if (index === launcher.selectedIndex) return Theme.accent;
                        if (delegateHover.hovered)            return Theme.bgHover;
                        return "transparent";
                    }

                    Behavior on color {
                        ColorAnimation { duration: 80 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        // App icon via freedesktop icon theme
                        Image {
                            id: appIcon
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            sourceSize.width: 24
                            sourceSize.height: 24
                            source: "image://icon/" + (modelData.icon || "application-x-executable")
                            asynchronous: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                color: index === launcher.selectedIndex ? Theme.bgSolid : Theme.fg
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.comment || modelData.genericName || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: index === launcher.selectedIndex
                                       ? Qt.rgba(0, 0, 0, 0.55)
                                       : Theme.fgDim
                                elide: Text.ElideRight
                                visible: text !== ""
                            }
                        }
                    }

                    HoverHandler {
                        id: delegateHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            launcher.selectedIndex = delegateItem.index;
                            launcher.launchApp(delegateItem.modelData);
                        }
                    }
                }
            }

            // ── Clipboard results list ────────────────────
            ListView {
                id: clipList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(filteredClipEntries.length, launcher.maxVisible) * 44
                clip: true
                model: filteredClipEntries
                currentIndex: launcher.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 80
                visible: launcher.activeTab === 1

                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && count > 0) {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }
                }

                delegate: Rectangle {
                    id: clipDelegate
                    required property var modelData
                    required property int index

                    width: clipList.width
                    height: 44
                    radius: 6
                    color: {
                        if (index === launcher.selectedIndex) return Theme.accent;
                        if (clipDelegateHover.hovered)        return Theme.bgHover;
                        return "transparent";
                    }

                    Behavior on color {
                        ColorAnimation { duration: 80 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        // Clipboard icon
                        Text {
                            Layout.preferredWidth: 24
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: Theme.iconClipboard
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                            color: index === launcher.selectedIndex ? Theme.bgSolid : Theme.fgDim
                        }

                        // Entry text (truncated)
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.content || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            color: index === launcher.selectedIndex ? Theme.bgSolid : Theme.fg
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        // Delete button
                        Text {
                            Layout.preferredWidth: 20
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: Theme.iconTrash
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            color: index === launcher.selectedIndex ? Theme.bgSolid : Theme.fgDim
                            opacity: clipDeleteHover.containsMouse ? 1.0 : 0.5
                            visible: clipDelegateHover.hovered || index === launcher.selectedIndex

                            Behavior on opacity { NumberAnimation { duration: 80 } }

                            MouseArea {
                                id: clipDeleteHover
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    launcher.deleteClipEntry(clipDelegate.modelData);
                                }
                            }
                        }
                    }

                    HoverHandler {
                        id: clipDelegateHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 28 // leave room for delete button
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            launcher.selectedIndex = clipDelegate.index;
                            launcher.copyClipEntry(clipDelegate.modelData);
                        }
                    }
                }
            }

            // Footer: result count
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (launcher.activeTab === 0) {
                        if (filteredApps.length === 0 && searchField.text !== "")
                            return "No results";
                        if (filteredApps.length > 0)
                            return filteredApps.length + " app" + (filteredApps.length !== 1 ? "s" : "");
                        return "";
                    } else {
                        if (filteredClipEntries.length === 0 && searchField.text !== "")
                            return "No results";
                        if (filteredClipEntries.length === 0 && !launcher.clipboardLoaded)
                            return "Loading...";
                        if (filteredClipEntries.length > 0)
                            return filteredClipEntries.length + " entr" + (filteredClipEntries.length !== 1 ? "ies" : "y");
                        if (launcher.clipboardLoaded)
                            return "Clipboard empty";
                        return "";
                    }
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.fgDim
            }
        }
    }
}
