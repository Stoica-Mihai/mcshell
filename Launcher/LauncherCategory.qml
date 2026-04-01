import QtQuick

// Base interface for launcher categories.
// All category tabs extend this and override the relevant properties/functions.
Item {
    visible: false
    width: 0; height: 0
    // ── Tab bar display ──
    property string tabLabel: ""
    property string tabIcon: ""
    property string searchPlaceholder: ""

    // ── Data model ──
    property var model: []

    // ── Disabled overlay (e.g. WiFi off, BT off) ──
    property bool disabledState: false
    property string disabledIcon: ""
    property string disabledHint: ""

    // ── Scanning overlay (shown when enabled but model empty) ──
    property bool scanningState: false
    property string scanningIcon: ""
    property string scanningHint: ""

    // ── Footer legend suffix ──
    property string legendHint: ""
    property string disabledLegendHint: ""  // shown when disabledState is true

    // ── Card delegate (Component producing a CarouselStrip) ──
    property Component cardDelegate: null

    // ── Lifecycle callbacks ──
    function onTabEnter() {}
    function onTabLeave() {}

    // ── Search callback ──
    function onSearch(text) {}

    // ── Activate selected item ──
    function onActivate(index) {}

    // ── Key handler — return true if consumed ──
    function onKeyPressed(event) { return false; }
}
