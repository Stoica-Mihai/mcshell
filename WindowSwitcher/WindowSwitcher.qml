import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Niri
import qs.Config
import qs.Widgets

PanelWindow {
    id: root

    property bool isOpen: false
    property int selectedIndex: 0
    property string _searchText: ""
    readonly property var _allWindows: Niri.windows ? Niri.windows.values : []
    readonly property var _filtered: {
        if (_searchText === "") return _allWindows;
        const q = _searchText.toLowerCase();
        return _allWindows.filter(w =>
            (w.title || "").toLowerCase().indexOf(q) >= 0 ||
            (w.appId || "").toLowerCase().indexOf(q) >= 0
        );
    }

    function open() {
        if (_allWindows.length === 0) return;
        isOpen = true;
        visible = true;
        _searchText = "";
        // Start on the focused window
        selectedIndex = 0;
        for (let i = 0; i < _filtered.length; i++) {
            if (_filtered[i].focused) { selectedIndex = i; break; }
        }
        searchField.forceActiveFocus();
    }

    function close() {
        isOpen = false;
        visible = false;
        _searchText = "";
    }

    function toggle() {
        if (isOpen) close(); else open();
    }

    function activate() {
        if (selectedIndex < 0 || selectedIndex >= _filtered.length) return;
        const win = _filtered[selectedIndex];
        Quickshell.execDetached({ command: ["niri", "msg", "action", "focus-window", "--id", String(win.id)] });
        close();
    }

    function _windowIcon(appId) {
        const entry = DesktopEntries.heuristicLookup(appId || "");
        const icon = entry ? entry.icon : appId;
        return "image://icon/" + (icon || "application-x-executable");
    }

    function navigate(delta) {
        if (_filtered.length === 0) return;
        selectedIndex = Math.max(0, Math.min(_filtered.length - 1, selectedIndex + delta));
    }

    // ── Window setup ────────────────────────────────────
    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "mcshell-window-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.backdrop
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // Search bar
    Rectangle {
        id: searchBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: cardArea.top
        anchors.bottomMargin: 20
        width: Math.min(600, parent.width - 80)
        height: 44
        radius: 10
        color: Theme.bg
        border.width: 1
        border.color: Theme.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: Theme.spacingMedium

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

                onTextChanged: {
                    root._searchText = text;
                    root.selectedIndex = 0;
                }

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.close();
                        event.accepted = true;
                        break;
                    case Qt.Key_Left:
                        root.navigate(-1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Right:
                        root.navigate(1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.activate();
                        event.accepted = true;
                        break;
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Switch window..."
                    color: Theme.fgDim
                    font: parent.font
                    visible: !parent.text
                }
            }
        }
    }

    // Cards area
    Item {
        id: cardArea
        anchors.centerIn: parent
        width: parent.width
        height: 400
        clip: true

        // Empty state
        Text {
            anchors.centerIn: parent
            visible: root._filtered.length === 0
            text: root._searchText ? "No matching windows" : "No windows open"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fgDim
        }

        // Sliding row
        Row {
            id: slidingRow
            x: _calcRowX()
            height: cardArea.height
            spacing: root._stripSpacing
            visible: root._filtered.length > 0

            Behavior on x {
                NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic }
            }

            Repeater {
                model: root._filtered

                Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: index === root.selectedIndex

                    width: isCurrent ? root._expandedWidth : root._stripWidth
                    height: cardArea.height
                    radius: Theme.radiusMedium
                    color: Theme.bg
                    border.width: isCurrent ? 2 : 1
                    border.color: isCurrent ? Theme.accent : Theme.border

                    Behavior on width {
                        NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic }
                    }

                    // Collapsed: icon only
                    Column {
                        anchors.centerIn: parent
                        visible: !card.isCurrent
                        spacing: Theme.spacingSmall

                        OptImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 48; height: 48
                            sourceSize: Qt.size(48, 48)
                            source: root._windowIcon(card.modelData.appId)
                        }
                    }

                    // Expanded: icon + title + details
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 48
                        visible: card.isCurrent
                        spacing: Theme.spacingLarge

                        OptImage {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 80
                            sourceSize: Qt.size(80, 80)
                            source: root._windowIcon(card.modelData.appId)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.appId || "Unknown"
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            font.bold: true
                            color: Theme.fg
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.title || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            color: Theme.fgDim
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                const parts = [];
                                if (card.modelData.focused) parts.push("Focused");
                                if (card.modelData.isFloating) parts.push("Floating");
                                return parts.join(Theme.separator);
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: card.modelData.focused ? Theme.accent : Theme.fgDim
                            horizontalAlignment: Text.AlignHCenter
                            visible: text !== ""
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.isCurrent) root.activate();
                            else root.selectedIndex = card.index;
                        }
                    }
                }
            }
        }
    }

    // Footer
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: cardArea.bottom
        anchors.topMargin: 16
        text: {
            if (root._filtered.length === 0) return "";
            return Theme.legend(
                (root.selectedIndex + 1) + " / " + root._filtered.length,
                Theme.hintNav,
                Theme.hintEnter + " focus",
                Theme.hintClose
            );
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.fgDim
    }

    // ── Carousel positioning ────────────────────────────
    readonly property int _sideCount: 4
    readonly property real _stripWidth: 100
    readonly property real _expandedWidth: 500
    readonly property real _stripSpacing: 8

    function _calcRowX() {
        if (root._filtered.length === 0) return cardArea.width / 2;
        const visibleLeft = Math.min(root.selectedIndex, _sideCount);
        const leftWidth = visibleLeft * (_stripWidth + _stripSpacing);
        const centerOffset = _expandedWidth / 2;
        return cardArea.width / 2 - leftWidth - centerOffset;
    }
}
