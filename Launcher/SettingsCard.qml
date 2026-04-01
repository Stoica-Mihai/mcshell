import QtQuick
import qs.Config

// Unified settings card that delegates to the right content based on category.
// Exposes a common navigation interface for the key handler.
Item {
    id: root

    required property string category  // "audio" | "display" | "power"
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
        if (loader.item && loader.item.adjustLeft) loader.item.adjustLeft();
    }
    function adjustRight() {
        if (loader.item && loader.item.adjustRight) loader.item.adjustRight();
    }

    // ── Collapsed icon ──
    readonly property string collapsedIcon: category === "audio" ? "\uf028"
        : category === "display" ? Theme.iconBrightness
        : Theme.iconShutdown

    // ── Load the right content ──
    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: root.category === "audio" ? audioComp
                       : root.category === "display" ? displayComp
                       : powerComp
        onLoaded: if (item) item.active = Qt.binding(() => root.active)
    }

    Component {
        id: audioComp
        SettingsAudio {}
    }

    Component {
        id: displayComp
        SettingsDisplay {}
    }

    Component {
        id: powerComp
        SettingsPower {}
    }
}
