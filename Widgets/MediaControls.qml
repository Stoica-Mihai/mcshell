import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Config

// Reusable media transport controls: prev, play/pause, next.
RowLayout {
    id: root

    property var player: null
    property int skipSize: Theme.iconSize
    property int playSize: Theme.iconSize
    property color controlColor: Theme.fg

    readonly property bool isPlaying: player
        ? player.playbackState === MprisPlaybackState.Playing : false

    IconButton {
        icon: Theme.iconPrev
        size: root.skipSize
        normalColor: root.controlColor
        visible: root.player && root.player.canGoPrevious
        onClicked: root.player.previous()
    }
    IconButton {
        icon: root.isPlaying ? Theme.iconPause : Theme.iconPlay
        size: root.playSize
        normalColor: root.controlColor
        onClicked: root.isPlaying ? root.player.pause() : root.player.play()
    }
    IconButton {
        icon: Theme.iconNext
        size: root.skipSize
        normalColor: root.controlColor
        visible: root.player && root.player.canGoNext
        onClicked: root.player.next()
    }
}
