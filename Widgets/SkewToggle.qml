import QtQuick
import qs.Config

// Parallelogram N-state toggle — `stateCount` picks 2-state (boolean) or
// 3-state (e.g. night-light off / manual / auto). The thumb slides
// linearly across the track between discrete positions.
//
// Optional `labels` array shows the current state name to the LEFT of the
// track (e.g. `labels: ["Off", "On"]`). Set to `[]` to suppress.
//
// Purely visual: parents own `state` and update it from their own key
// handlers. mcshell's config popups are keyboard-driven so no mouse
// handling lives on the widget itself.
Item {
    id: root

    property int state: 0            // 0 .. stateCount - 1
    property int stateCount: 2

    // Optional per-state track colour. When empty a sensible default
    // palette is derived from stateCount.
    property var colors: []

    // Optional per-state label shown to the left of the track. Defaults to
    // ["Off", "On"] for boolean toggles so callers don't have to repeat it.
    property var labels: stateCount === 2 ? ["Off", "On"] : []
    property color labelColor: state === 0 ? Theme.fgDim : Theme.fg

    property int trackHeight: 16
    property int thumbMargin: 2
    property int stopGap: 4          // extra pixels per additional stop
    readonly property int thumbWidth: trackHeight - thumbMargin

    // Auto-scales with stateCount so 3-state has enough travel to look
    // distinct from 2-state. Callers can override for a specific width.
    property int trackWidth: thumbMargin * 2 + thumbWidth + (thumbWidth + stopGap) * Math.max(1, stateCount - 1)

    readonly property bool _hasLabel: labels.length > state && labels[state] !== ""

    implicitWidth: trackWidth + (_hasLabel ? labelText.implicitWidth + Theme.spacingSmall : 0)
    implicitHeight: Math.max(trackHeight, _hasLabel ? labelText.implicitHeight : 0)

    readonly property int _steps: Math.max(1, stateCount - 1)
    readonly property real _travel: trackWidth - thumbWidth - thumbMargin * 2
    readonly property real _thumbX: thumbMargin + state * _travel / _steps

    readonly property color _trackColor: {
        if (colors.length === stateCount) return colors[state];
        // Default palette: dim off-state, accent for on-states, and a
        // distinct highlight on the final state for 3+ state toggles so
        // the last stop doesn't visually collapse into the middle one.
        if (state === 0) return Theme.overlay;
        if (state === stateCount - 1 && stateCount >= 3) return Theme.green;
        return Theme.accent;
    }

    Text {
        id: labelText
        visible: root._hasLabel
        anchors.right: track.left
        anchors.rightMargin: Theme.spacingSmall
        anchors.verticalCenter: track.verticalCenter
        text: root._hasLabel ? root.labels[root.state] : ""
        color: root.labelColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeTiny
        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
    }

    // Track
    SkewRect {
        id: track
        width: root.trackWidth
        height: root.trackHeight
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        fillColor: root._trackColor
        strokeColor: Theme.withAlpha(Theme.fg, 0.08)
        strokeWidth: 1

        Behavior on fillColor { ColorAnimation { duration: Theme.animNormal } }

        // Thumb
        SkewRect {
            width: root.thumbWidth
            height: root.trackHeight - root.thumbMargin * 2
            y: root.thumbMargin
            x: root._thumbX
            fillColor: root.state === 0 ? Theme.fg : Theme.accentFg

            Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
            Behavior on fillColor { ColorAnimation { duration: Theme.animNormal } }
        }
    }
}
