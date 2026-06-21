import QtQuick
import QtQuick.Layouts
import qs.Config

// Launcher search bar: skewed background, tab row with animated underline,
// search icon + field. Hosted by AppLauncher, which sets anchors/size and
// drives state through the `launcher` reference. Re-exposes the search field
// and tab-highlight controls the launcher needs.
Item {
    id: searchBar

    property var launcher
    property alias searchField: searchField
    readonly property bool tabAnimating: leftAnim.running || rightAnim.running

    function snapToTab(idx) { tabHighlight._snapToTab(idx); }
    function animateToTab(idx) { tabHighlight.animateTo(idx); }

    Canvas {
        id: searchBarBg
        anchors.fill: parent
        Connections {
            target: Theme
            function onSurfaceContainerChanged() { searchBarBg.requestPaint(); }
            function onOutlineVariantChanged() { searchBarBg.requestPaint(); }
        }
        Connections {
            target: UserSettings
            function onBlurEnabledChanged() { searchBarBg.requestPaint(); }
        }
        onPaint: {
            var ctx = getContext("2d"), s = Theme.barDiagSlant;
            ctx.clearRect(0, 0, width, height);
            ctx.beginPath();
            // Search bar leans opposite to the bar segments: map onto the
            // shared tracer with ox=s/2, sp=-s/2 → points (s,0)(width,0)(width-s,h)(0,h).
            Theme.traceParallelogram(ctx, s / 2, width - s, height, -s / 2);
            ctx.fillStyle = Theme.withAlpha(Theme.surfaceContainer,
                UserSettings.blurEnabled ? Theme.blurAlpha : Theme.searchBarAlpha);
            ctx.fill();
            ctx.strokeStyle = Theme.outlineVariant;
            ctx.lineWidth = Theme.strokeThin;
            ctx.stroke();
        }
    }

    // ── Tab underline highlight ────────────────────
    Item {
        id: tabHighlight
        anchors.fill: parent
        visible: false

        readonly property real _pad: 4
        property real _lineLeft: 0
        property real _lineRight: 0

        NumberAnimation {
            id: leftAnim
            target: tabHighlight; property: "_lineLeft"
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            id: rightAnim
            target: tabHighlight; property: "_lineRight"
            easing.type: Easing.InOutQuad
        }

        // ── Snap (no animation) ──
        property var _pendingConn: null
        function _snapToTab(idx) {
            if (_pendingConn) { _pendingConn.enabled = false; _pendingConn = null; }
            const item = tabRepeater.itemAt(idx);
            if (!item) return;
            if (item.width > 0) {
                _applySnap(item);
            } else {
                _pendingConn = item.widthChanged.connect(function() {
                    if (item.width > 0) {
                        item.widthChanged.disconnect(arguments.callee);
                        tabHighlight._applySnap(item);
                    }
                });
            }
        }

        function _applySnap(item) {
            const pos = item.mapToItem(searchBar, 0, 0);
            leftAnim.stop(); rightAnim.stop();
            _lineLeft = pos.x - _pad;
            _lineRight = pos.x + item.width + _pad;
            visible = true;
        }

        // ── Animated transition ──
        function animateTo(idx) {
            const item = tabRepeater.itemAt(idx);
            if (!item) return;
            if (!visible) { _snapToTab(idx); return; }
            const pos = item.mapToItem(searchBar, 0, 0);
            const targetLeft = pos.x - _pad;
            const targetRight = pos.x + item.width + _pad;
            const movingRight = targetLeft > _lineLeft;

            leftAnim.stop(); rightAnim.stop();
            leftAnim.to = targetLeft;
            rightAnim.to = targetRight;
            // Leading edge is fast, trailing is slower
            leftAnim.duration = movingRight ? 250 : 120;
            rightAnim.duration = movingRight ? 120 : 250;
            leftAnim.start();
            rightAnim.start();
        }

        // ── The underline ──
        Rectangle {
            x: tabHighlight._lineLeft
            y: searchBar.height - 3
            width: tabHighlight._lineRight - tabHighlight._lineLeft
            height: 2
            radius: 1
            color: searchBar.launcher.inView ? Theme.accent : Theme.fgDim
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: Theme.spacingMedium

        // Tab buttons — driven by categories
        Repeater {
            id: tabRepeater
            model: searchBar.launcher.categories

            delegate: Item {
                required property var modelData
                required property int index
                Layout.preferredWidth: tabContent.implicitWidth + 16
                Layout.preferredHeight: 28

                RowLayout {
                    id: tabContent
                    anchors.centerIn: parent
                    spacing: Theme.spacingTiny

                    Text {
                        text: modelData.tabIcon
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fg
                    }

                    Text {
                        text: modelData.tabLabel
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fg
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: searchBar.launcher.switchTab(index)
                }
            }
        }

        // Separator
        Rectangle { width: Theme.strokeThin; Layout.preferredHeight: 20; color: Theme.outlineVariant }

        // Search icon
        Text {
            text: Theme.iconSearch
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.fg
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

            onTextChanged: searchBar.launcher._handleSearchInput(text)

            Keys.onPressed: event => {
                const launcher = searchBar.launcher;
                // Category-specific keys always get first chance
                if (launcher.activeCategory.onKeyPressed(event)) {
                    event.accepted = true;
                    return;
                }
                if (launcher.inView)      event.accepted = launcher._viewKey(event.key);
                else if (launcher.inList) event.accepted = launcher._listKey(event.key);
                else if (launcher.inEdit) event.accepted = launcher._editKey(event.key);
            }

            Keys.onReleased: event => {
                if (searchBar.launcher.activeCategory.onKeyReleased?.(event))
                    event.accepted = true;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: searchBar.launcher.activeCategory.searchPlaceholder
                color: Theme.fg
                font: parent.font
                visible: !parent.text
            }
        }
    }
}
