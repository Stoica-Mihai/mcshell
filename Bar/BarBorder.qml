import QtQuick
import QtQuick.Shapes
import qs.Config

// Static border for a parallelogram bar segment.
// Supports "solid" (single accent color) and "gradient" (theme gradient) styles.
// Style is controlled by UserSettings.barBorderStyle.
Item {
    id: root

    required property var pts
    property real borderWidth: 1

    readonly property bool useGradient: UserSettings.barBorderStyle === "gradient"

    function _buildStops() {
        var stops = Theme.barBorderGradient;
        var newStops = [];
        for (var i = 0; i < stops.length; i++) {
            var s = Qt.createQmlObject(
                'import QtQuick; GradientStop { position: ' + stops[i].position +
                '; color: "' + stops[i].color + '" }', grad);
            newStops.push(s);
        }
        grad.stops = newStops;
    }

    Connections {
        target: Theme
        function onAccentChanged() { root._buildStops(); }
        function onSecondaryChanged() { root._buildStops(); }
        function onTertiaryChanged() { root._buildStops(); }
    }

    // Solid border (simple stroke)
    Shape {
        anchors.fill: parent
        visible: !root.useGradient
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.accent
            strokeWidth: root.borderWidth

            startX: root.pts[0][0]; startY: root.pts[0][1]
            PathLine { x: root.pts[1][0]; y: root.pts[1][1] }
            PathLine { x: root.pts[2][0]; y: root.pts[2][1] }
            PathLine { x: root.pts[3][0]; y: root.pts[3][1] }
            PathLine { x: root.pts[0][0]; y: root.pts[0][1] }
        }
    }

    // Gradient border (OddEvenFill ring with linear gradient)
    Shape {
        anchors.fill: parent
        visible: root.useGradient
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: 0

            fillGradient: LinearGradient {
                id: grad
                x1: 0; y1: root.height / 2
                x2: root.width; y2: root.height / 2

                Component.onCompleted: root._buildStops()
            }

            // Outer polygon
            startX: root.pts[0][0]; startY: root.pts[0][1]
            PathLine { x: root.pts[1][0]; y: root.pts[1][1] }
            PathLine { x: root.pts[2][0]; y: root.pts[2][1] }
            PathLine { x: root.pts[3][0]; y: root.pts[3][1] }
            PathLine { x: root.pts[0][0]; y: root.pts[0][1] }

            // Inner polygon (inset)
            PathMove {
                x: root.pts[0][0] + root.borderWidth
                y: root.pts[0][1] + root.borderWidth
            }
            PathLine {
                x: root.pts[1][0] - root.borderWidth
                y: root.pts[1][1] + root.borderWidth
            }
            PathLine {
                x: root.pts[2][0] - root.borderWidth
                y: root.pts[2][1] - root.borderWidth
            }
            PathLine {
                x: root.pts[3][0] + root.borderWidth
                y: root.pts[3][1] - root.borderWidth
            }
            PathLine {
                x: root.pts[0][0] + root.borderWidth
                y: root.pts[0][1] + root.borderWidth
            }
        }
    }
}
