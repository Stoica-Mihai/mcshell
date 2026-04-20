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

    // ── Pill mode: ◀ [ value ] ▶ with the value on a skewed pill ──
    RowLayout {
        id: pillRow
        visible: root.pillValue
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: Theme.iconArrowLeft
            visible: root._arrowsVisible
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMini
            color: root.textColor
            opacity: 0.5
        }

        SkewPill {
            text: root._currentLabel
            textColor: root.enabled ? root.textColor : Theme.fgDim
            Layout.preferredHeight: implicitHeight
        }

        Text {
            text: Theme.iconArrowRight
            visible: root._arrowsVisible
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMini
            color: root.textColor
            opacity: 0.5
        }
    }
}
