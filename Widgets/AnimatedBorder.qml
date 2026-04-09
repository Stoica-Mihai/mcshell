import QtQuick
import qs.Config

// Animated border that "draws" itself on the card's parallelogram shape.
// Multiple animation styles — set `style` to switch. Adding a new animation
// is just a new function in _styles and a name in the styles list.
// Trigger by setting active: true.
Item {
    id: root

    property bool active: false
    property string style: "midpoint"
    property color color: Theme.accent
    property real thickness: 2
    property int duration: Theme.animCarousel

    // Available style names (for settings UI)
    readonly property var styles: Object.keys(_styles)

    property real _progress: 0
    on_ProgressChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()

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

    // ── Shared drawing helpers ────────────────────────
    // Polygon vertices as [[x,y], ...] from parallelogram coordinates
    function _verts(tl, tr, bl, br, h) {
        return [[tl, 0], [tr, 0], [br, h], [bl, h]];
    }

    // Draw a line segment growing from its midpoint outward by factor p
    function _edgeFromCenter(ctx, x1, y1, x2, y2, p) {
        var mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
        var dx = (x2 - x1) * p / 2, dy = (y2 - y1) * p / 2;
        ctx.moveTo(mx - dx, my - dy);
        ctx.lineTo(mx + dx, my + dy);
    }

    // Draw all four edges growing from midpoints
    function _allEdgesFromCenter(ctx, v, p) {
        for (var i = 0; i < v.length; i++) {
            var next = (i + 1) % v.length;
            _edgeFromCenter(ctx, v[i][0], v[i][1], v[next][0], v[next][1], p);
        }
    }

    // ── Animation styles ─────────────────────────────
    // Each takes (ctx, tl, tr, bl, br, h, p) where p is 0→1 progress.
    readonly property var _styles: ({
        // Edges grow from their midpoints outward
        "midpoint": function(ctx, tl, tr, bl, br, h, p) {
            root._allEdgesFromCenter(ctx, root._verts(tl, tr, bl, br, h), p);
        },

        // Border traces clockwise from top-center
        "clockwise": function(ctx, tl, tr, bl, br, h, p) {
            var midTop = (tl + tr) / 2;
            var pts = [[midTop, 0], [tr, 0], [br, h], [bl, h], [tl, 0], [midTop, 0]];
            var lens = [];
            var total = 0;
            for (var i = 0; i < pts.length - 1; i++) {
                var dx = pts[i+1][0] - pts[i][0], dy = pts[i+1][1] - pts[i][1];
                lens.push(Math.sqrt(dx * dx + dy * dy));
                total += lens[i];
            }
            var remain = total * p;
            ctx.moveTo(pts[0][0], pts[0][1]);
            for (var j = 0; j < lens.length && remain > 0; j++) {
                var seg = Math.min(remain, lens[j]);
                var t = seg / lens[j];
                ctx.lineTo(
                    pts[j][0] + (pts[j+1][0] - pts[j][0]) * t,
                    pts[j][1] + (pts[j+1][1] - pts[j][1]) * t
                );
                remain -= seg;
            }
        },

        // Corners appear first, then edges fill in
        "corners": function(ctx, tl, tr, bl, br, h, p) {
            var v = root._verts(tl, tr, bl, br, h);
            var cornerLen = 20;
            var t = Math.min(1, p * 2.5);
            for (var i = 0; i < v.length; i++) {
                var prev = (i + v.length - 1) % v.length;
                var next = (i + 1) % v.length;
                var cx = v[i][0], cy = v[i][1];
                // Direction toward previous vertex
                var d1x = v[prev][0] - cx, d1y = v[prev][1] - cy;
                var l1 = Math.sqrt(d1x * d1x + d1y * d1y);
                // Direction toward next vertex
                var d2x = v[next][0] - cx, d2y = v[next][1] - cy;
                var l2 = Math.sqrt(d2x * d2x + d2y * d2y);
                var len = cornerLen * t;
                ctx.moveTo(cx + d1x / l1 * Math.min(len, l1), cy + d1y / l1 * Math.min(len, l1));
                ctx.lineTo(cx, cy);
                ctx.lineTo(cx + d2x / l2 * Math.min(len, l2), cy + d2y / l2 * Math.min(len, l2));
            }
            if (p > 0.4)
                root._allEdgesFromCenter(ctx, v, (p - 0.4) / 0.6);
        },

        // All edges appear simultaneously with opacity fade
        "fade": function(ctx, tl, tr, bl, br, h, p) {
            ctx.globalAlpha = p;
            var v = root._verts(tl, tr, bl, br, h);
            ctx.moveTo(v[0][0], v[0][1]);
            for (var i = 1; i < v.length; i++)
                ctx.lineTo(v[i][0], v[i][1]);
            ctx.closePath();
        }
    })

    Canvas {
        id: canvas

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

            var tl = -skewPx + ox;
            var tr = w - skewPx + ox;
            var bl = skewPx + ox;
            var br = w + skewPx + ox;

            ctx.strokeStyle = root.color;
            ctx.lineWidth = root.thickness;
            ctx.lineCap = "square";
            ctx.globalAlpha = 1;
            ctx.beginPath();

            var drawFn = root._styles[root.style] || root._styles["midpoint"];
            drawFn(ctx, tl, tr, bl, br, h, root._progress);

            ctx.stroke();
        }
    }
}
