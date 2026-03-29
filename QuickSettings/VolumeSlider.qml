import QtQuick
import Quickshell.Services.Pipewire
import qs.Config

Item {
    id: root

    readonly property PwNode sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property real rawVolume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    implicitWidth: parent ? parent.width : 240
    implicitHeight: slider.implicitHeight

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function refresh() {}

    ControlSlider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        label: "Volume"
        value: root.rawVolume
        muted: root.muted
        icon: root.muted       ? "\uf466"
            : root.rawVolume < 0.3 ? "\uf026"
            : root.rawVolume < 0.7 ? "\uf027"
            :                        "\uf028"
        onMoved: newValue => {
            if (root.sink?.audio)
                root.sink.audio.volume = Math.max(0, Math.min(1.0, newValue));
        }
        onIconClicked: {
            if (root.sink?.audio)
                root.sink.audio.muted = !root.sink.audio.muted;
        }
    }
}
