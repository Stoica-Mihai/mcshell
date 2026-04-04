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
    property bool enabled: true

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
            if (root.model.length === 0) return "";
            if (!root.enabled) return root.model[root.currentIndex];
            return Theme.iconArrowLeft + "  " + root.model[root.currentIndex] + "  " + Theme.iconArrowRight;
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: root.enabled ? root.textColor : Theme.fgDim
    }
}
