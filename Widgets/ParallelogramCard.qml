import QtQuick
import QtQuick.Shapes
import qs.Config

// Reusable parallelogram-shaped card with antialiased edges.
// Provides: background fill, content slot, and optional border ring.
Item {
    id: card

    default property alias contentData: contentArea.data

    // Content delegate properties (accessible via parent.* from content children)
    property alias isCurrent: contentArea.isCurrent

    // Border
    property bool showBorder: false
    property color borderColor: Theme.outlineVariant
    property real borderWidth: 1

    // Background
    property color backgroundColor: Theme.bg

    // Stroke on background shape (used by DisabledCard for thin outline)
    property color bgStrokeColor: "transparent"
    property real bgStrokeWidth: 0

    // Whether content should be skewed to match the parallelogram
    property bool skewContent: false

    // Skew geometry
    readonly property real _skew: Theme.cardSkew
    readonly property real _skewPx: _skew * height / 2
    readonly property real _tl: -_skewPx
    readonly property real _tr: width - _skewPx
    readonly property real _bl: _skewPx
    readonly property real _br: width + _skewPx

    // Background fill
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: card.backgroundColor
            strokeColor: card.bgStrokeColor
            strokeWidth: card.bgStrokeWidth

            startX: card._tl; startY: 0
            PathLine { x: card._tr; y: 0 }
            PathLine { x: card._br; y: card.height }
            PathLine { x: card._bl; y: card.height }
            PathLine { x: card._tl; y: 0 }
        }
    }

    // Content area — optionally skewed with smooth layer edges
    Item {
        id: contentWrapper
        anchors.fill: parent
        anchors.margins: card.skewContent ? -1 : 0

        layer.enabled: card.skewContent
        layer.smooth: card.skewContent

        transform: card.skewContent ? skewTransform : null

        Matrix4x4 {
            id: skewTransform
            matrix: Qt.matrix4x4(
                1, card._skew, 0, -card._skew * contentWrapper.height / 2,
                0, 1,          0, 0,
                0, 0,          1, 0,
                0, 0,          0, 1
            )
        }

        Item {
            id: contentArea
            anchors.fill: parent
            anchors.margins: card.skewContent ? 1 : 0

            // Exposed to content delegates via parent.*
            property bool isCurrent: false
            property real cardPadding: 14
        }
    }

    // Border ring — OddEvenFill for uniform width on all edges
    Shape {
        anchors.fill: parent
        visible: card.showBorder
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: card.borderColor
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: 0

            startX: card._tl; startY: 0
            PathLine { x: card._tr; y: 0 }
            PathLine { x: card._br; y: card.height }
            PathLine { x: card._bl; y: card.height }
            PathLine { x: card._tl; y: 0 }

            PathMove { x: card._tl + card.borderWidth; y: card.borderWidth }
            PathLine { x: card._tr - card.borderWidth; y: card.borderWidth }
            PathLine { x: card._br - card.borderWidth; y: card.height - card.borderWidth }
            PathLine { x: card._bl + card.borderWidth; y: card.height - card.borderWidth }
            PathLine { x: card._tl + card.borderWidth; y: card.borderWidth }
        }
    }
}
