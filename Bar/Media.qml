import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Config
import qs.Widgets

Item {
    id: root

    implicitWidth: row.visible ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight
    visible: row.visible

    // Pick the first active player, prefer one that's playing
    property var player: {
        if (!Mpris.players || !Mpris.players.values) return null;

        const all = Mpris.players.values;
        let playing = null;
        let fallback = null;

        for (let i = 0; i < all.length; i++) {
            const p = all[i];
            if (!p || !p.canPlay) continue;
            if (p.playbackState === MprisPlaybackState.Playing) {
                playing = p;
                break;
            }
            if (!fallback) fallback = p;
        }
        return playing || fallback;
    }

    property bool isPlaying: player ? player.playbackState === MprisPlaybackState.Playing : false
    property string title: player ? (player.trackTitle || "").replace(/[\r\n]/g, "") : ""
    property string artist: player ? (player.trackArtist || "") : ""

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        visible: root.player !== null && root.title !== ""

        // Previous
        IconButton {
            icon: "\uf048"
            size: Theme.iconSize - 2
            normalColor: Theme.fgDim
            visible: root.player && root.player.canGoPrevious
            onClicked: root.player.previous()
        }

        // Play/Pause
        IconButton {
            icon: root.isPlaying ? "\uf04c" : "\uf04b"
            onClicked: root.isPlaying ? root.player.pause() : root.player.play()
        }

        // Next
        IconButton {
            icon: "\uf051"
            size: Theme.iconSize - 2
            normalColor: Theme.fgDim
            visible: root.player && root.player.canGoNext
            onClicked: root.player.next()
        }

        // Track info: "Artist - Title" (truncated)
        Text {
            Layout.maximumWidth: 200
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            text: root.artist ? root.artist + " - " + root.title : root.title
        }
    }
}
