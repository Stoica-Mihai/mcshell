import QtQuick
import qs.Config

// Lightweight parallelogram shape primitive. Used as a building block by
// SkewPill, SkewToggle, SkewCheck and anywhere the skewed-morphism style
// needs a filled quadrilateral (accent stripes, section-label ticks, etc.).
//
// `skewAmount` defaults to Theme.cardSkew so it matches the bar/card
// aesthetic. Set negative values to lean the other way.
//
// Canvas (not Shape) for per-pixel AA on Wayland layer-shell surfaces,
// which lack MSAA. Bounds widened by `pad` so the slanted protrusions
// aren't clipped — matches ParallelogramCard's bgCanvas pattern.
Item {
    id: root

    property color fillColor: Theme.accent
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property real skewAmount: Theme.cardSkew

    readonly property real _skewPx: skewAmount * height / 2
    readonly property real _absSkew: Math.abs(_skewPx)

    Canvas {
        id: canvas
        readonly property real pad: root._absSkew + Math.max(root.strokeWidth, 0.5)
        x: -pad
        width: root.width + pad * 2
        height: root.height

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const ox = pad;
            ctx.beginPath();
            ctx.moveTo(-root._skewPx + ox,             0);
            ctx.lineTo(root.width - root._skewPx + ox, 0);
            ctx.lineTo(root.width + root._skewPx + ox, root.height);
            ctx.lineTo(root._skewPx + ox,              root.height);
            ctx.closePath();
            ctx.fillStyle = root.fillColor;
            ctx.fill();
            if (root.strokeWidth > 0) {
                ctx.strokeStyle = root.strokeColor;
                ctx.lineWidth = root.strokeWidth;
                ctx.lineJoin = "miter";
                ctx.stroke();
            }
        }

        Connections {
            target: root
            function onWidthChanged()       { canvas.requestPaint(); }
            function onHeightChanged()      { canvas.requestPaint(); }
            function onSkewAmountChanged()  { canvas.requestPaint(); }
            function onFillColorChanged()   { canvas.requestPaint(); }
            function onStrokeColorChanged() { canvas.requestPaint(); }
            function onStrokeWidthChanged() { canvas.requestPaint(); }
        }
    }
}
