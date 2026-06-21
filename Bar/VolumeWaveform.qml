import QtQuick
import qs.Config
import qs.Widgets

// Volume waveform — ascending bars scaled by volume level.
// Hover tooltip shows the percentage. Same footprint as the CPU waveform.
Item {
    id: root

    required property real rawVolume
    required property int volume
    required property bool muted

    signal leftClicked()
    signal rightClicked()
    signal middleClicked()
    signal wheel(var event)

    property bool active: false
    readonly property bool hovered: mouse.containsMouse

    implicitWidth: bars.implicitWidth
    implicitHeight: Theme.iconSize

    // Each bar maps to a volume segment, fill ramps 0→1 within its segment.
    // Computed once per rawVolume change and diffed against the prior
    // array by Repeater — no per-delegate JS callback fan-out.
    readonly property var _barHeights: Theme.thresholdBars(rawVolume)

    WaveformBars {
        id: bars
        anchors.centerIn: parent
        // Volume bars cap at 10 px (vs. 14 px for SysWaveform) — keeps
        // the capsule height balanced against the slash overlay below.
        referenceHeight: 10
        model: root._barHeights
        color: root.muted ? Theme.fgDim : Theme.accent
    }

    // Mute slash — diagonal line through the bars
    Rectangle {
        visible: root.muted
        anchors.centerIn: bars
        width: Math.sqrt(bars.implicitWidth * bars.implicitWidth + 14 * 14)
        height: 1.5
        radius: 1
        color: Theme.red
        rotation: -35
    }

    ActiveUnderline { visible: root.active }

    BarClickArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onLeftClicked:   root.leftClicked()
        onRightClicked:  root.rightClicked()
        onMiddleClicked: root.middleClicked()
        onWheel: event => root.wheel(event)
    }

    ThemedTooltip {
        showWhen: root.hovered && !root.active
        text: root.muted ? "Muted" : root.volume + "%"
    }
}
