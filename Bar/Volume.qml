import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Config

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // ── PipeWire native binding ─────────────────────────
    readonly property PwNode sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property real rawVolume: sink?.audio?.volume ?? 0
    readonly property int volume: Math.round(rawVolume * 100)
    readonly property bool muted: sink?.audio?.muted ?? false

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function setVolume(vol) {
        if (!sink?.audio) return;
        sink.audio.volume = Math.max(0, Math.min(1.0, vol));
    }

    function toggleMute() {
        if (!sink?.audio) return;
        sink.audio.muted = !sink.audio.muted;
    }

    // ── UI ──────────────────────────────────────────────
    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            color: root.muted ? Theme.red : Theme.fg
            font.family: "Symbols Nerd Font"
            font.pixelSize: Theme.iconSize
            text: root.muted       ? "\uf466"
                : root.volume < 30 ? "\uf026"
                : root.volume < 70 ? "\uf027"
                :                    "\uf028"
        }

        Text {
            color: root.muted ? Theme.red : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            text: root.volume + "%"
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: root.toggleMute()
        onWheel: wheel => {
            const step = 0.02;
            if (wheel.angleDelta.y > 0)
                root.setVolume(root.rawVolume + step);
            else
                root.setVolume(root.rawVolume - step);
        }
    }
}
