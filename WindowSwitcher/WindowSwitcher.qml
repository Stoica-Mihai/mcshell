import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Qs.NiriIpc
import qs.Config
import qs.Core
import qs.Widgets

OverlayWindow {
    id: root
    namespace: "mcshell-window-switcher"

    property bool isOpen: false
    property int selectedIndex: 0
    property string _searchText: ""
    property int _currentId: -1
    property int _previousId: -1

    // Track focus changes to maintain current/previous
    readonly property int _focusedId: {
        for (const w of (Niri.windows ? Niri.windows.values : [])) {
            if (w.focused) return w.id;
        }
        return -1;
    }
    on_FocusedIdChanged: {
        if (_focusedId < 0 || isOpen) return;
        if (_focusedId !== _currentId) {
            _previousId = _currentId;
            _currentId = _focusedId;
        }
    }

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
        searchBar.reset();
        // Always start at 0 so a stale index from the previous session can't
        // outlive a window that's been closed in the meantime.
        selectedIndex = 0;
        // Then prefer the previously focused window for quick alt+tab toggle.
        if (_previousId >= 0) {
            for (let i = 0; i < _filtered.length; i++) {
                if (_filtered[i].id === _previousId) { selectedIndex = i; break; }
            }
        }
    }

    function close() {
        isOpen = false;
        visible = false;
        _searchText = "";
    }

    function toggle() {
        if (isOpen) navigate(1); else open();
    }

    function activate() {
        if (selectedIndex < 0 || selectedIndex >= _filtered.length) return;
        const win = _filtered[selectedIndex];
        close();
        Quickshell.execDetached({ command: ["niri", "msg", "action", "focus-window", "--id", String(win.id)] });
    }

    function _windowIcon(appId) {
        const entry = DesktopEntries.heuristicLookup(appId || "");
        const icon = entry ? entry.icon : appId;
        return "image://icon/" + (icon || "application-x-executable");
    }

    function navigate(delta) {
        if (_filtered.length === 0) return;
        selectedIndex = (selectedIndex + delta + _filtered.length) % _filtered.length;
    }

    // ── Window setup ────────────────────────────────────
    visible: false
    anchors { top: true; bottom: true; left: true; right: true }

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.backdrop
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // Search bar — ParallelogramCard provides the skewed background
    ParallelogramCard {
        id: searchBarCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: cardArea.top
        anchors.bottomMargin: 20
        width: Math.min(600, parent.width - 80)
        height: 44
        backgroundColor: Theme.bg
        showBorder: true
        borderColor: searchBar.field.activeFocus ? Theme.accent : Theme.border
        _skew: Theme.cardSkew * cardArea.height / height

        StyledTextField {
            id: searchBar
            anchors.fill: parent
            anchors.leftMargin: Math.abs(searchBarCard._skew * searchBarCard.height / 2) + 4
            anchors.rightMargin: Math.abs(searchBarCard._skew * searchBarCard.height / 2) + 4
            color: "transparent"
            border.width: 0
            icon: Theme.iconSearch
            placeholder: "Switch window..."

            field.onTextChanged: {
                root._searchText = searchBar.text;
                root.selectedIndex = 0;
            }

            field.Keys.onPressed: event => {
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

            field.Keys.onReleased: event => {
                if (event.key === Qt.Key_Alt) {
                    root.activate();
                    event.accepted = true;
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

                ParallelogramCard {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool _isCurrent: index === root.selectedIndex

                    width: _isCurrent ? root._expandedWidth : root._stripWidth
                    height: cardArea.height
                    showBorder: true
                    borderColor: _isCurrent ? Theme.accent : Theme.border
                    borderWidth: _isCurrent ? 2 : 1

                    Behavior on width {
                        NumberAnimation { duration: Theme.animCarousel; easing.type: Easing.OutCubic }
                    }

                    // Collapsed: icon only
                    Column {
                        anchors.centerIn: parent
                        visible: !card._isCurrent
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
                        visible: card._isCurrent
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
                            font.pixelSize: Theme.fontSizeLarge
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
                            if (card._isCurrent) root.activate();
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
                `${root.selectedIndex + 1} / ${root._filtered.length}`,
                Theme.hintNav,
                `${Theme.hintEnter} focus`,
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
