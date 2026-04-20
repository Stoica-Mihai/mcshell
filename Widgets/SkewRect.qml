import QtQuick
import QtQuick.Shapes
import qs.Config

// Lightweight parallelogram shape primitive. Used as a building block by
// SkewPill, BoolToggle, SkewCheck and anywhere the skewed-morphism style
// needs a filled quadrilateral (accent stripes, section-label ticks, etc.).
//
// `skewAmount` defaults to Theme.cardSkew so it matches the bar/card
// aesthetic. Set negative values to lean the other way.
Item {
    id: root

    property color fillColor: Theme.accent
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property real skewAmount: Theme.cardSkew

    readonly property real _skewPx: skewAmount * height / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fillColor
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth

            startX: -root._skewPx; startY: 0
            PathLine { x: root.width - root._skewPx; y: 0 }
            PathLine { x: root.width + root._skewPx; y: root.height }
            PathLine { x: root._skewPx;              y: root.height }
            PathLine { x: -root._skewPx;             y: 0 }
        }
    }
}
