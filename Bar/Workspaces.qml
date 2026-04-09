import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Niri
import qs.Config
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

    // Unique appIds per workspace — { workspaceId: [appId, appId, ...] }
    readonly property var _appsPerWorkspace: {
        const windows = Niri.windows ? Niri.windows.values : [];
        const map = {};
        for (let i = 0; i < windows.length; i++) {
            const w = windows[i];
            const wsId = w.workspaceId;
            if (wsId < 0) continue;
            if (!map[wsId]) map[wsId] = [];
            if (map[wsId].indexOf(w.appId) < 0)
                map[wsId].push(w.appId);
        }
        return map;
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
                readonly property var apps: root._appsPerWorkspace[modelData.id] || []
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
                        readonly property real _oldSweep: index < wsItem._fromCount ? root._sweepForCount(wsItem._fromCount) : 0
                        readonly property real _newSweep: index < wsItem._toCount ? root._sweepForCount(wsItem._toCount) : 0
                        readonly property real _sweep: _oldSweep + (_newSweep - _oldSweep) * wsItem._t

                        // Start angle — cumulative sum of previous segments' animated sweeps
                        readonly property real _start: {
                            let angle = root._startOffset;
                            const from = wsItem._fromCount;
                            const to = wsItem._toCount;
                            const t = wsItem._t;
                            for (let i = 0; i < index; i++) {
                                const oldSw = i < from ? root._sweepForCount(from) : 0;
                                const newSw = i < to ? root._sweepForCount(to) : 0;
                                angle += oldSw + (newSw - oldSw) * t + root._gapDeg;
                            }
                            return angle;
                        }

                        readonly property bool _visible: _sweep > 0.5
                        readonly property color _segColor: wsItem.urgent ? Theme.red : Theme.ringColors[index]

                        ShapePath {
                            fillColor: "transparent"
                            strokeWidth: root._strokeWidth
                            capStyle: ShapePath.RoundCap
                            strokeColor: seg._visible
                                ? Qt.rgba(seg._segColor.r, seg._segColor.g, seg._segColor.b, wsItem.focused ? 1.0 : Theme.opacityDim)
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
                         : wsItem.focused ? Theme.accent
                         : wsItem.appCount > 0 ? Theme.fgDim
                         : Theme.overlayHover
                    Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.dispatch(["focus-workspace", wsItem.modelData.idx.toString()])
                }

                ThemedTooltip {
                    showWhen: wsMouse.containsMouse && wsItem.appCount > 0
                    text: wsItem.apps.join("\n")
                }
            }
        }
    }
}
