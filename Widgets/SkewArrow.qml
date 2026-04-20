import QtQuick
import QtQuick.Shapes
import qs.Config

// Triangular arrow that shares its flat edge with a SkewPill's diagonal
// side — left-direction arrow abuts the pill's left edge, right-direction
// abuts the right edge. Matches the pill's `skewAmount` so the two
// diagonals align exactly; use the same height for a clean silhouette.
Item {
    id: root

    property string direction: "right"   // "left" | "right"
    property color fillColor: Theme.accent
    property real skewAmount: Theme.cardSkew

    readonly property real _sp: skewAmount * height / 2
    readonly property bool _left: direction === "left"

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Vertex positions so the back edge shares exactly with the
        // pill's matching side when placed adjacent in a Row (spacing=0):
        //
        //   Left arrow (tip on the left):
        //     tip      (0, h/2)
        //     top-right(w - sp, 0)    ← = pill's top-left in screen space
        //     bot-right(w + sp, h)    ← = pill's bottom-left
        //
        //   Right arrow (tip on the right):
        //     top-left (-sp, 0)       ← = pill's top-right
        //     tip      (w, h/2)
        //     bot-left (sp, h)        ← = pill's bottom-right
        //
        // The back corners may land outside the Item's nominal bbox on
        // one side — Shape can render past bounds without issue, and the
        // Row's layout cursor stays on Item.width so the seam is clean.
        ShapePath {
            fillColor: root.fillColor
            strokeColor: "transparent"
            strokeWidth: 0

            startX: root._left ? 0 : -root._sp
            startY: root._left ? root.height / 2 : 0

            PathLine {
                x: root._left ? root.width - root._sp : root.width
                y: root._left ? 0 : root.height / 2
            }
            PathLine {
                x: root._left ? root.width + root._sp : root._sp
                y: root.height
            }
            PathLine {
                x: root._left ? 0 : -root._sp
                y: root._left ? root.height / 2 : 0
            }
        }
    }
}
