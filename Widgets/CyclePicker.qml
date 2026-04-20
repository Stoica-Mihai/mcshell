import QtQuick
import QtQuick.Layouts
import qs.Config

// Inline left/right cycle picker: ◀ value ▶
// Wraps around at both ends.
//
// Default rendering is a single Text line. Set `pillValue: true` to wrap
// the value in a SkewPill between the arrows (skewed-morphism style).
//
// Usage:
//   CyclePicker {
//       model: ["Tonal", "Vibrant", "Neutral"]
//       currentIndex: 0
//       onIndexChanged: idx => doSomething(idx)
//   }
Item {
    id: root

    property var model: []
    property int currentIndex: 0
    property color textColor: Theme.accent
    property bool pillValue: false

    readonly property int _safeIndex: Math.max(0, Math.min(currentIndex, model.length - 1))
    readonly property string _currentLabel: model.length > 0 ? model[_safeIndex] : ""
    readonly property bool _arrowsVisible: root.enabled && _currentLabel !== ""

    signal indexChanged(int idx)

    implicitWidth: pillValue ? pillRow.implicitWidth : textLabel.implicitWidth
    implicitHeight: pillValue ? pillRow.implicitHeight : textLabel.implicitHeight

    function cycleLeft() {
        if (!enabled || model.length === 0) return;
        currentIndex = (currentIndex - 1 + model.length) % model.length;
        indexChanged(currentIndex);
    }

    function cycleRight() {
        if (!enabled || model.length === 0) return;
        currentIndex = (currentIndex + 1) % model.length;
        indexChanged(currentIndex);
    }

    // ── Default: single-line text rendering ──
    Text {
        id: textLabel
        visible: !root.pillValue
        anchors.centerIn: parent
        text: {
            if (root._currentLabel === "") return "";
            if (!root.enabled) return root._currentLabel;
            return `${Theme.iconArrowLeft}  ${root._currentLabel}  ${Theme.iconArrowRight}`;
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: root.enabled ? root.textColor : Theme.fgDim
    }

    // ── Pill mode: ◀ [ value ] ▶ built as three adjoining skewed shapes.
    // Arrows share their inside edge with the pill's diagonal so the whole
    // thing reads as one continuous glyph. Stronger skew than Theme.cardSkew
    // so the arrow triangles look like arrows, not nearly-rectangles.
    // Negative skew → top shifts right relative to bottom (italic-lean).
    readonly property real _pillSkew: -0.3

    // Pin the pill to the widest label in the current model so it stays
    // the same size as the value cycles. Measured imperatively on model
    // changes — a readonly block binding would register a dependency on
    // TextMetrics.advanceWidth and then re-fire every time this function
    // itself mutates the shared metrics, causing a binding loop.
    TextMetrics {
        id: _pillMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMini
    }

    property real _maxLabelWidth: 0

    function _recomputeMaxLabelWidth() {
        if (!root.pillValue) return;
        let max = 0;
        for (let i = 0; i < model.length; i++) {
            _pillMetrics.text = String(model[i]);
            if (_pillMetrics.advanceWidth > max) max = _pillMetrics.advanceWidth;
        }
        _maxLabelWidth = max;
    }

    onModelChanged: _recomputeMaxLabelWidth()
    Component.onCompleted: _recomputeMaxLabelWidth()

    Row {
        id: pillRow
        visible: root.pillValue
        anchors.centerIn: parent
        spacing: 0

        SkewArrow {
            direction: "left"
            width: 10
            height: pill.implicitHeight
            skewAmount: root._pillSkew
            fillColor: root.textColor
            visible: root._arrowsVisible
        }

        SkewPill {
            id: pill
            text: root._currentLabel
            textColor: root.enabled ? root.textColor : Theme.fgDim
            skewAmount: root._pillSkew
            hPadding: 12
            fixedWidth: Math.ceil(root._maxLabelWidth) + hPadding * 2
        }

        SkewArrow {
            direction: "right"
            width: 10
            height: pill.implicitHeight
            skewAmount: root._pillSkew
            fillColor: root.textColor
            visible: root._arrowsVisible
        }
    }
}
