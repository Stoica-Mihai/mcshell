import QtQuick

// Lazy windowed model for large JS arrays.
// Exposes a growing subset of `sourceModel` as `items`, extending
// by `pageSize` entries as the watched `currentIndex` approaches
// the loaded boundary. Avoids creating hundreds of QML delegates
// at once — only materializes items as the user navigates.
//
// Usage:
//   LazyModel {
//       id: lazy
//       sourceModel: myFullArray
//       currentIndex: selectedIndex
//   }
//   Repeater { model: lazy.items }
QtObject {
    id: root

    // ── Input ──
    property var sourceModel: []
    property int currentIndex: 0
    property int initialSize: 50   // first batch — enough for instant display
    property int growSize: 100     // extend by this much when approaching the edge

    // ── Output ──
    readonly property int count: _loadedEnd
    readonly property int totalCount: sourceModel.length

    // ── Internal ──
    property int _loadedEnd: 0

    function reset() {
        _loadedEnd = 0;
        _ensureLoaded(currentIndex);
    }

    function _ensureLoaded(idx) {
        if (sourceModel.length === 0) { _loadedEnd = 0; return; }
        const buffer = 20;
        if (idx + buffer <= _loadedEnd && _loadedEnd > 0) return;
        const size = _loadedEnd === 0 ? initialSize : growSize;
        _loadedEnd = Math.min(idx + size, sourceModel.length);
    }

    onCurrentIndexChanged: _ensureLoaded(currentIndex)
    onSourceModelChanged: reset()
}
