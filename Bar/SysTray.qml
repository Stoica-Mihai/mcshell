import QtQuick
import QtQuick.Shapes
import Quickshell.Services.SystemTray
import qs.Config
import qs.Widgets

// Collapsed tray indicator — segmented ring with item count, matching workspace style.
// Each tray icon gets a ring segment. Click opens the tray icons panel.
Item {
    id: root

    property bool menuVisible: false
    property bool expanded: false

    signal showTrayMenu(var item)
    signal toggleExpand()

    readonly property int itemCount: SystemTray.items.values.length
    readonly property bool hovered: mouse.containsMouse

    readonly property int _ringSize: 22
    readonly property real _ringCenter: _ringSize / 2
    readonly property real _ringRadius: (_ringSize - _strokeWidth) / 2
    readonly property int _strokeWidth: 2
    readonly property real _gapDeg: 20
    readonly property int _maxSegments: Theme.ringColors.length

    function _sweepForCount(n) {
        return n > 0 ? (360 - _gapDeg * n) / n : 0;
    }

    // Animated segment transition
    property int _fromCount: 0
    property int _toCount: 0
    property real _t: 1.0

    onItemCountChanged: {
        _fromCount = _toCount;
        _toCount = Math.min(itemCount, _maxSegments);
        _t = 0;
        _anim.restart();
    }

    NumberAnimation {
        id: _anim
        target: root
        property: "_t"
        from: 0; to: 1
        duration: 600
        easing.type: Easing.InOutCubic
    }

    Component.onCompleted: {
        _toCount = Math.min(itemCount, _maxSegments);
        _t = 1.0;
    }

    implicitWidth: _ringSize
    implicitHeight: _ringSize

    // Segmented ring
    Repeater {
        model: root._maxSegments

        Shape {
            id: seg
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property real _oldSweep: index < root._fromCount ? root._sweepForCount(root._fromCount) : 0
            readonly property real _newSweep: index < root._toCount ? root._sweepForCount(root._toCount) : 0
            readonly property real _sweep: _oldSweep + (_newSweep - _oldSweep) * root._t

            readonly property real _start: {
                let angle = -90;
                for (let i = 0; i < index; i++) {
                    const oldSw = i < root._fromCount ? root._sweepForCount(root._fromCount) : 0;
                    const newSw = i < root._toCount ? root._sweepForCount(root._toCount) : 0;
                    angle += oldSw + (newSw - oldSw) * root._t + root._gapDeg;
                }
                return angle;
            }

            readonly property bool _visible: _sweep > 0.5
            readonly property color _segColor: Theme.ringColors[index]

            ShapePath {
                fillColor: "transparent"
                strokeWidth: root._strokeWidth
                capStyle: ShapePath.RoundCap
                strokeColor: seg._visible
                    ? Qt.rgba(seg._segColor.r, seg._segColor.g, seg._segColor.b,
                              root.expanded || root.hovered ? 1.0 : Theme.opacityDim)
                    : "transparent"
                Behavior on strokeColor { ColorAnimation { duration: Theme.animSmooth } }

                PathAngleArc {
                    centerX: root._ringCenter
                    centerY: root._ringCenter
                    radiusX: root._ringRadius
                    radiusY: root._ringRadius
                    startAngle: seg._start
                    sweepAngle: seg._sweep
                }
            }
        }
    }

    // Count
    Text {
        anchors.centerIn: parent
        text: root.itemCount
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMini
        font.bold: true
        color: root.expanded || root.hovered ? Theme.accent
             : root.itemCount > 0 ? Theme.fgDim
             : Theme.overlayHover

        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
    }

    ActiveUnderline { visible: root.expanded }

    ThemedTooltip {
        showWhen: root.hovered && !root.expanded && root.itemCount > 0
        text: {
            if (!root.hovered) return "";
            const items = SystemTray.items.values;
            const names = [];
            for (let i = 0; i < items.length; i++)
                names.push(items[i].tooltipTitle || items[i].name || items[i].id || "Unknown");
            return names.join("\n");
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleExpand()
        onCanceled: root.toggleExpand()
    }
}
