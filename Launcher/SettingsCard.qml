import QtQuick
import qs.Config
import qs.Widgets

// Unified settings card that loads content from a source URL.
// Renders shared header (icon + title + subtitle) from panel properties,
// provides scrollable container, and common navigation interface.
Item {
    id: root

    property string source: ""
    property bool active: false
    readonly property string panelLegend: loader.item?.panelLegend ?? Theme.legend(Theme.hintUpDown, Theme.hintEnter + " select", Theme.hintBack)
    signal actionRequested(string action)

    // ── Common navigation interface ──
    function navigateUp() {
        if (loader.item && loader.item.navigateUp) loader.item.navigateUp();
        _ensureVisible();
    }
    function navigateDown() {
        if (loader.item && loader.item.navigateDown) loader.item.navigateDown();
        _ensureVisible();
    }
    function activateItem() {
        if (loader.item && loader.item.activateItem) loader.item.activateItem();
    }
    function adjustLeft() {
        if (loader.item && loader.item.adjustLeft) return loader.item.adjustLeft();
        return false;
    }
    function adjustRight() {
        if (loader.item && loader.item.adjustRight) return loader.item.adjustRight();
        return false;
    }
    function resetSelection() {
        if (loader.item && loader.item.resetSelection) loader.item.resetSelection();
        flick.contentY = 0;
    }

    // Auto-scroll to keep the selected SettingsRow visible.
    // Walks the loaded panel's children to find the one with selected === true.
    function _ensureVisible() {
        if (!loader.item) return;
        const row = _findSelected(loader.item);
        if (!row) return;
        const mapped = row.mapToItem(wrapper, 0, 0);
        if (mapped.y < flick.contentY)
            flick.contentY = Math.max(0, mapped.y - 8);
        else if (mapped.y + row.height > flick.contentY + flick.height)
            flick.contentY = mapped.y + row.height - flick.height + 8;
    }

    function _findSelected(item) {
        if (item.selected === true && 'selectedColor' in item)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const found = _findSelected(item.children[i]);
            if (found) return found;
        }
        return null;
    }

    // ── Scrollable container with shared header ──
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: wrapper.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        SmoothWheelHandler { target: flick }

        Column {
            id: wrapper
            width: parent.width
            spacing: Theme.spacingTiny

            // Shared header — reads properties from loaded panel
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: loader.item?.headerIcon ?? ""
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSizeMedium
                color: loader.item?.headerColor ?? Theme.accent
                visible: text !== ""
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: loader.item?.headerTitle ?? ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
                color: Theme.fg
                visible: text !== ""
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: loader.item?.headerSubtitle ?? ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.fgDim
                visible: text !== ""
            }
            Item { width: 1; height: 8 }

            // Panel body
            Loader {
                id: loader
                width: parent.width
                source: root.source
                onLoaded: {
                    if (!item) return;
                    item.active = Qt.binding(() => root.active);
                    if (item.actionRequested)
                        item.actionRequested.connect(root.actionRequested);
                }
            }
        }
    }
}
