import QtQuick
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
    property color backgroundColor: Theme.surfaceContainer

    // Stroke on background shape (used by DisabledCard for thin outline)
    property color bgStrokeColor: "transparent"
    property real bgStrokeWidth: 0

    // Whether content should be skewed to match the parallelogram
    property bool skewContent: false

    // Skew geometry (public — derived values are useful for callers placing
    // visuals along the slanted edges).
    property real skew: Theme.cardSkew
    readonly property real skewPx: skew * height / 2
    readonly property real tl: -skewPx
    readonly property real tr: width - skewPx
    readonly property real bl: skewPx
    readonly property real br: width + skewPx
    readonly property real absSkew: Math.abs(skewPx)

    // Background fill — Canvas (not Shape) for per-pixel AA on Wayland
    // layer-shell surfaces, which lack MSAA. Bounds widened by `pad` so
    // the slanted protrusions aren't clipped.
    Canvas {
        id: bgCanvas
        readonly property real pad: card.absSkew
        x: -pad
        width: card.width + pad * 2
        height: card.height

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const ox = pad;
            ctx.beginPath();
            ctx.moveTo(card.tl + ox, 0);
            ctx.lineTo(card.tr + ox, 0);
            ctx.lineTo(card.br + ox, card.height);
            ctx.lineTo(card.bl + ox, card.height);
            ctx.closePath();
            ctx.fillStyle = card.backgroundColor;
            ctx.fill();
            if (card.bgStrokeWidth > 0) {
                ctx.strokeStyle = card.bgStrokeColor;
                ctx.lineWidth = card.bgStrokeWidth;
                ctx.stroke();
            }
        }

        Connections {
            target: card
            function onSkewPxChanged() { bgCanvas.requestPaint(); }
            function onWidthChanged() { bgCanvas.requestPaint(); }
            function onHeightChanged() { bgCanvas.requestPaint(); }
            function onBackgroundColorChanged() { bgCanvas.requestPaint(); }
            function onBgStrokeColorChanged() { bgCanvas.requestPaint(); }
            function onBgStrokeWidthChanged() { bgCanvas.requestPaint(); }
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
                1, card.skew, 0, -card.skew * contentWrapper.height / 2,
                0, 1,         0, 0,
                0, 0,         1, 0,
                0, 0,         0, 1
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

    // Border outline — Canvas for the same AA reason as the bg fill.
    Canvas {
        id: borderCanvas
        readonly property real pad: card.absSkew + card.borderWidth
        x: -pad
        width: card.width + pad * 2
        height: card.height
        visible: card.showBorder

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const ox = pad;
            ctx.beginPath();
            ctx.moveTo(card.tl + ox, 0);
            ctx.lineTo(card.tr + ox, 0);
            ctx.lineTo(card.br + ox, card.height);
            ctx.lineTo(card.bl + ox, card.height);
            ctx.closePath();
            ctx.strokeStyle = card.borderColor;
            ctx.lineWidth = card.borderWidth;
            ctx.lineJoin = "miter";
            ctx.stroke();
        }

        Connections {
            target: card
            function onSkewPxChanged() { borderCanvas.requestPaint(); }
            function onWidthChanged() { borderCanvas.requestPaint(); }
            function onHeightChanged() { borderCanvas.requestPaint(); }
            function onBorderColorChanged() { borderCanvas.requestPaint(); }
            function onBorderWidthChanged() { borderCanvas.requestPaint(); }
        }
    }
}
