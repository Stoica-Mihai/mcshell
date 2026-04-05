import QtQuick
import qs.Config

// Animated border that "draws" itself from edge midpoints outward.
// Uses the card's parallelogram skew so it conforms to any card shape.
// Trigger by setting active: true.
Item {
    id: root

    property bool active: false
    property color color: Theme.accent
    property real thickness: 2
    property int duration: Theme.animCarousel

    property real _progress: 0
    on_ProgressChanged: canvas.requestPaint()

    onActiveChanged: {
        if (active) {
            reverseAnim.stop();
            _progress = 0;
            progressAnim.restart();
        } else {
            progressAnim.stop();
            reverseAnim.restart();
        }
    }

    NumberAnimation {
        id: progressAnim
        target: root
        property: "_progress"
        from: 0; to: 1
        duration: root.duration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: reverseAnim
        target: root
        property: "_progress"
        to: 0
        duration: root.duration / 2
        easing.type: Easing.InCubic
    }

    Canvas {
        id: canvas

        // Pad canvas to fit parallelogram vertices that extend beyond parent bounds
        readonly property real _skewPx: Theme.cardSkew * root.height / 2
        readonly property real _pad: Math.ceil(Math.abs(_skewPx)) + root.thickness

        x: -_pad
        width: root.width + _pad * 2
        height: root.height
        visible: root._progress > 0

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (root._progress <= 0) return;

            var ox = _pad;
            var skewPx = _skewPx;
            var w = root.width;
            var h = root.height;
            var p = root._progress;

            // Parallelogram vertices in canvas-local coordinates
            var tl = -skewPx + ox;
            var tr = w - skewPx + ox;
            var bl = skewPx + ox;
            var br = w + skewPx + ox;

            ctx.strokeStyle = root.color;
            ctx.lineWidth = root.thickness;
            ctx.lineCap = "square";
            ctx.beginPath();

            // Each edge grows from its midpoint outward
            function edge(x1, y1, x2, y2) {
                var mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
                var dx = (x2 - x1) * p / 2, dy = (y2 - y1) * p / 2;
                ctx.moveTo(mx - dx, my - dy);
                ctx.lineTo(mx + dx, my + dy);
            }

            edge(tl, 0, tr, 0);     // top
            edge(tr, 0, br, h);     // right
            edge(br, h, bl, h);     // bottom
            edge(bl, h, tl, 0);     // left

            ctx.stroke();
        }
    }
}
