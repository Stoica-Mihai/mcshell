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

    // Skew geometry
    property real _skew: Theme.cardSkew
    readonly property real _skewPx: _skew * height / 2
    readonly property real _tl: -_skewPx
    readonly property real _tr: width - _skewPx
    readonly property real _bl: _skewPx
    readonly property real _br: width + _skewPx
    readonly property real _absSkew: Math.abs(_skewPx)

    // Background fill — Canvas with native 2D antialiasing. Wayland
    // layer-shell surfaces have no MSAA backing, so Shape's slanted
    // fill edges stair-step. Canvas's `ctx.fill()` antialiases per-pixel
    // and avoids that. Bounds are widened by `_pad` (matching the border
    // canvas) so the parallelogram protrusions aren't clipped.
    Canvas {
        id: bgCanvas
        readonly property real _pad: card._absSkew
        x: -_pad
        width: card.width + _pad * 2
        height: card.height

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const ox = _pad;
            ctx.beginPath();
            ctx.moveTo(card._tl + ox, 0);
            ctx.lineTo(card._tr + ox, 0);
            ctx.lineTo(card._br + ox, card.height);
            ctx.lineTo(card._bl + ox, card.height);
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
            function on_SkewPxChanged() { bgCanvas.requestPaint(); }
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

    // Border outline — Canvas with native 2D antialiasing. Same trick
    // AnimatedBorder uses: extend Canvas bounds by `_pad` so the
    // parallelogram protrusions and stroke aren't clipped.
    Canvas {
        id: borderCanvas
        readonly property real _pad: card._absSkew + card.borderWidth
        x: -_pad
        width: card.width + _pad * 2
        height: card.height
        visible: card.showBorder

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const ox = _pad;
            ctx.beginPath();
            ctx.moveTo(card._tl + ox, 0);
            ctx.lineTo(card._tr + ox, 0);
            ctx.lineTo(card._br + ox, card.height);
            ctx.lineTo(card._bl + ox, card.height);
            ctx.closePath();
            ctx.strokeStyle = card.borderColor;
            ctx.lineWidth = card.borderWidth;
            ctx.lineJoin = "miter";
            ctx.stroke();
        }

        Connections {
            target: card
            function on_SkewPxChanged() { borderCanvas.requestPaint(); }
            function onWidthChanged() { borderCanvas.requestPaint(); }
            function onHeightChanged() { borderCanvas.requestPaint(); }
            function onBorderColorChanged() { borderCanvas.requestPaint(); }
            function onBorderWidthChanged() { borderCanvas.requestPaint(); }
        }
    }
}
