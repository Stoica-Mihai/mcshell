import QtQuick
import qs.Config

// Parallelogram pill button. Use for confirm/cancel pairs and other
// interactive primary/ghost actions where the rounded TextButton would
// break the skewed-morphism vocabulary (ScreenCast picker, dialogs that
// host SkewRect chrome elsewhere).
//
// `primary: true` paints with accent fill; otherwise it's a transparent
// pill with an outline stroke and dim label.
Item {
    id: root

    property string label: ""
    property bool primary: false
    property real skewAmount: -0.3
    signal clicked()

    implicitWidth: text.implicitWidth + 32
    implicitHeight: 30
    opacity: enabled ? 1.0 : 0.4

    SkewRect {
        anchors.fill: parent
        skewAmount: root.skewAmount
        fillColor: root.primary
            ? (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
            : (mouse.containsMouse ? Theme.withAlpha(Theme.fg, 0.06) : "transparent")
        strokeColor: root.primary ? "transparent" : Theme.outline
        strokeWidth: root.primary ? 0 : 1

        Behavior on fillColor { ColorAnimation { duration: Theme.animFast } }
    }

    Text {
        id: text
        anchors.centerIn: parent
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.bold: root.primary
        color: root.primary ? Theme.accentFg : Theme.fg
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
