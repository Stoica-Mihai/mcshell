import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Qs.NiriIpc
import qs.Config
import qs.Core
import qs.Widgets

Item {
    id: root

    property string screenName: ""

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Reactive workspace list — filtered by screen, sorted by index
    readonly property var workspaces: {
        const all = Niri.workspaces.values;
        const filtered = [];
        for (let i = 0; i < all.length; i++) {
            if (all[i].output === root.screenName)
                filtered.push(all[i]);
        }
        filtered.sort((a, b) => a.idx - b.idx);
        return filtered;
    }

    readonly property int _ringSize: 22
    readonly property real _ringCenter: _ringSize / 2
    readonly property real _ringRadius: (_ringSize - _strokeWidth) / 2
    readonly property int _strokeWidth: 2
    readonly property real _gapDeg: 20
    readonly property real _startOffset: -90
    readonly property int _maxSegments: Theme.ringColors.length
    readonly property int _animDuration: 600

    function _sweepForCount(n) {
        return n > 0 ? (360 - _gapDeg * n) / n : 0;
    }

    MouseArea {
        anchors.fill: row
        onWheel: wheel => {
            Niri.dispatch(wheel.angleDelta.y > 0
                ? ["focus-workspace-up"]
                : ["focus-workspace-down"]);
        }
    }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall

        Repeater {
            model: root.workspaces

            Item {
                id: wsItem
                required property var modelData

                property bool focused: modelData.focused
                property bool urgent: modelData.urgent
                readonly property var apps: NiriAppsCache.appsByWorkspace[modelData.id] || []
                readonly property int appCount: Math.min(apps.length, root._maxSegments)

                // Transition driver — single animated value from 0 to 1
                property int _fromCount: 0
                property int _toCount: 0
                property real _t: 1.0

                onAppCountChanged: {
                    _fromCount = _toCount;
                    _toCount = appCount;
                    _t = 0;
                    _anim.restart();
                }

                // Per-count full sweep — hoisted so the 8 Shape segments
                // don't each recompute it twice on every _t tick.
                readonly property real _oldFullSweep: root._sweepForCount(_fromCount)
                readonly property real _newFullSweep: root._sweepForCount(_toCount)

                // Cumulative segment start angles — recomputed once per _t /
                // _fromCount / _toCount change instead of inside each of the 8
                // Shape segments. Length matches root._maxSegments so every
                // segment delegate can read _cumStart[index] without an
                // out-of-bounds undefined.
                readonly property var _cumStart: {
                    const from = _fromCount;
                    const to = _toCount;
                    const t = _t;
                    const oldFull = _oldFullSweep;
                    const newFull = _newFullSweep;
                    const out = new Array(root._maxSegments);
                    let angle = root._startOffset;
                    for (let i = 0; i < root._maxSegments; i++) {
                        out[i] = angle;
                        const oldSw = i < from ? oldFull : 0;
                        const newSw = i < to ? newFull : 0;
                        angle += oldSw + (newSw - oldSw) * t + root._gapDeg;
                    }
                    return out;
                }

                NumberAnimation {
                    id: _anim
                    target: wsItem
                    property: "_t"
                    from: 0; to: 1
                    duration: root._animDuration
                    easing.type: Easing.InOutCubic
                }

                implicitWidth: root._ringSize
                implicitHeight: root._ringSize

                Repeater {
                    model: root._maxSegments

                    Shape {
                        id: seg
                        required property int index
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        // Interpolated sweep for this segment
                        readonly property real _oldSweep: index < wsItem._fromCount ? wsItem._oldFullSweep : 0
                        readonly property real _newSweep: index < wsItem._toCount ? wsItem._newFullSweep : 0
                        readonly property real _sweep: _oldSweep + (_newSweep - _oldSweep) * wsItem._t

                        // Start angle — O(1) lookup into the precomputed
                        // cumulative-sweep array on wsItem (one array
                        // allocation per _t tick instead of O(N²) work
                        // across 8 segment bindings).
                        readonly property real _start: wsItem._cumStart[index]

                        readonly property bool _visible: _sweep > 0.5
                        readonly property color _segColor: wsItem.urgent ? Theme.red : Theme.ringColors[index]

                        ShapePath {
                            fillColor: "transparent"
                            strokeWidth: root._strokeWidth
                            capStyle: ShapePath.RoundCap
                            strokeColor: seg._visible
                                ? Theme.withAlpha(seg._segColor, wsItem.focused ? 1.0 : Theme.opacityDim)
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

                // Workspace number
                Text {
                    anchors.centerIn: parent
                    text: wsItem.modelData.idx
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    font.bold: true
                    color: wsItem.urgent ? Theme.red
                         : wsItem.appCount > 0 || wsItem.focused ? Theme.fg
                         : Theme.overlayHover
                    Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.dispatch(["focus-workspace", wsItem.modelData.idx.toString()])
                    onCanceled: Niri.dispatch(["focus-workspace", wsItem.modelData.idx.toString()])
                }

                ThemedTooltip {
                    showWhen: wsMouse.containsMouse && wsItem.appCount > 0
                    text: wsItem.apps.join("\n")
                }
            }
        }
    }
}
