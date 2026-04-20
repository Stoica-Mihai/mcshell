import QtQuick
import qs.Config

// Small parallelogram pill with centered text. Used for cycle-picker
// values, compact badges, vendor chips, etc.
Item {
    id: root

    property string text: ""
    property color fillColor: Theme.withAlpha(Theme.accent, 0.12)
    property color strokeColor: Theme.withAlpha(Theme.accent, 0.25)
    property color textColor: Theme.accent
    property int fontSize: Theme.fontSizeMini
    property bool bold: false
    property int hPadding: 10
    property int vPadding: 2
    property real skewAmount: Theme.cardSkew
    // When > 0, lock the pill to this width instead of sizing to content.
    // Callers cycling values should set this to the widest expected label
    // so the pill doesn't jitter as the text changes.
    property real fixedWidth: -1

    implicitWidth: fixedWidth > 0
        ? fixedWidth
        : Math.max(label.implicitWidth + hPadding * 2, 40)
    implicitHeight: label.implicitHeight + vPadding * 2

    SkewRect {
        anchors.fill: parent
        fillColor: root.fillColor
        strokeColor: root.strokeColor
        strokeWidth: 1
        skewAmount: root.skewAmount
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.fontFamily
        font.pixelSize: root.fontSize
        font.bold: root.bold
        color: root.textColor
    }
}
