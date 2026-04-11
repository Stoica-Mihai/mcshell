import QtQuick
import QtQuick.Shapes
import qs.Config

// Filled parallelogram + matching border for a bar segment.
// Both the Shape fill and the BarBorder ring share the same 4-point polygon,
// so callers only need to supply `pts` and `fillColor`.
Item {
    id: root

    required property var pts
    required property color fillColor

    Shape {
        id: bg
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.fillColor
            strokeColor: "transparent"
            startX: root.pts[0][0]; startY: root.pts[0][1]
            PathLine { x: root.pts[1][0]; y: root.pts[1][1] }
            PathLine { x: root.pts[2][0]; y: root.pts[2][1] }
            PathLine { x: root.pts[3][0]; y: root.pts[3][1] }
            PathLine { x: root.pts[0][0]; y: root.pts[0][1] }
        }
    }

    BarBorder {
        anchors.fill: parent
        pts: root.pts
    }
}
