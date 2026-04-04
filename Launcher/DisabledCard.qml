import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Config

// Single centered card for status states (disabled, scanning, etc.).
// Uses the same parallelogram shape as CarouselStrip.
Item {
    id: root

    property string icon: ""
    property string hint: ""
    property color iconColor: Theme.red
    property real iconOpacity: 0.4

    width: 500
    height: 350

    // Skew — must match CarouselStrip._skew
    readonly property real _skew: -0.03
    readonly property real _skewPx: _skew * height / 2
    readonly property real _tl: -_skewPx
    readonly property real _tr: width - _skewPx
    readonly property real _bl: _skewPx
    readonly property real _br: width + _skewPx

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Theme.bg
            strokeColor: Theme.border
            strokeWidth: 1

            startX: root._tl; startY: 0
            PathLine { x: root._tr; y: 0 }
            PathLine { x: root._br; y: root.height }
            PathLine { x: root._bl; y: root.height }
            PathLine { x: root._tl; y: 0 }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingLarge
        width: parent.width - 40

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            font.family: Theme.iconFont
            font.pixelSize: 48
            color: root.iconColor
            opacity: root.iconOpacity
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.hint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fgDim
        }
    }
}
