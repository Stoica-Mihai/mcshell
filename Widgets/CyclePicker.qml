import QtQuick
import qs.Config

// Inline left/right cycle picker: ◀ value ▶
// Wraps around at both ends.
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

    readonly property int _safeIndex: Math.max(0, Math.min(currentIndex, model.length - 1))
    readonly property string _currentLabel: model.length > 0 ? model[_safeIndex] : ""

    signal indexChanged(int idx)

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

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

    Text {
        id: label
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
}
