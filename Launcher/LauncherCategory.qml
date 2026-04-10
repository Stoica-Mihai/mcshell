import QtQuick

// Base interface for launcher categories.
// All category tabs extend this and override the relevant properties/functions.
Item {
    visible: false
    width: 0; height: 0
    // ── Tab bar display ──
    property string tabName: ""
    property string tabLabel: ""
    property string tabIcon: ""
    property string searchPlaceholder: ""

    // ── Data model (lazy-loaded) ──
    property var model: []
    property var _sourceData: []
    property int _loadedCount: 0

    function setItems(items, startIndex) {
        _sourceData = items;
        const w = 15;
        _loadedCount = Math.min(items.length, Math.max(w, (startIndex || 0) + w));
        model = items.length <= w ? items : items.slice(0, _loadedCount);
    }

    Timer {
        id: _growTimer
        interval: 350
        onTriggered: model = _sourceData.slice(0, _loadedCount)
    }

    function growItems(selectedIndex) {
        if (_loadedCount >= _sourceData.length) return;
        const need = selectedIndex + 8;
        if (need > _loadedCount) {
            _loadedCount = Math.min(_sourceData.length, need + 8);
            _growTimer.restart();
        }
    }

    // ── Disabled overlay (e.g. WiFi off, BT off) ──
    property bool disabledState: false
    property string disabledIcon: ""
    property string disabledHint: ""

    // ── Scanning overlay (shown when enabled but model empty) ──
    property bool scanningState: false
    property string scanningIcon: ""
    property string scanningHint: ""

    // ── Supported navigation levels ──
    // Override to add "edit" for categories that drill into cards.
    property var supportedModes: ["view", "list"]

    // ── Footer legend suffix ──
    property string legendHint: ""
    property string disabledLegendHint: ""  // shown when disabledState is true
    property bool legendOverride: false     // when true, legendHint replaces the full footer at Level 2

    // ── Card delegate (Component producing a CarouselStrip) ──
    property Component cardDelegate: null

    // ── Lifecycle callbacks ──
    function onTabEnter() {}
    function onTabLeave() {}

    function onOpenTarget(target) {}

    // ── Search callback ──
    function onSearch(text) {}

    // Shared substring filter — normalizes query, returns new array of matching items.
    function filterByQuery(text, items, matchFn) {
        const query = (text || "").toLowerCase().trim();
        const results = [];
        for (let i = 0; i < items.length; i++) {
            if (query === "" || matchFn(items[i], query))
                results.push(items[i]);
        }
        return results;
    }

    // ── Bounds check helper ──
    function _validIndex(index) {
        return index >= 0 && index < _sourceData.length;
    }

    // ── Activate selected item ──
    function onActivate(index) {}

    // ── Key handler — return true if consumed ──
    function onKeyPressed(event) { return false; }
}
