import QtQuick
import qs.Config

// Unified settings card that loads content from a source URL.
// Exposes a common navigation interface for the key handler.
Item {
    id: root

    property string source: ""
    property bool active: false

    // ── Common navigation interface ──
    function navigateUp() {
        if (loader.item && loader.item.navigateUp) loader.item.navigateUp();
    }
    function navigateDown() {
        if (loader.item && loader.item.navigateDown) loader.item.navigateDown();
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
    }

    // ── Load the right content ──
    Loader {
        id: loader
        anchors.fill: parent
        source: root.source
        onLoaded: if (item) item.active = Qt.binding(() => root.active)
    }
}
