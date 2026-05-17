import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Config
import qs.Widgets

// MPRIS media-popup body: album art, track info, seek bar, transport row,
// per-player volume slider, and chip picker for switching between active
// MPRIS players.
//
// Hosted inside StatusBar's `sharedDropdown` AnimatedPopup. The consumer
// sets `visible`/`enabled` (gates layout); internal Connections and
// FrameAnimation gate on the explicit `active` prop so binding evaluation
// stops when the panel is closed even if the consumer leaves `visible`
// alone for some reason.
ColumnLayout {
    id: root

    // ── Public API ─────────────────────────────────────────
    // The Bar/Media.qml wrapper around the MPRIS player.
    required property var media
    // Drives FrameAnimation + Connections gating. Consumer binds this to
    // the dropdown's activePanel === "media" check.
    property bool active: false

    spacing: Theme.spacingMedium

    // ── Internal state ─────────────────────────────────────
    // trackLen: pure binding (noctalia-shell pattern). Quickshell's
    // MprisPlayer.length emits lengthChanged, so the binding refreshes
    // reactively. Sentinel guard rejects "infinite" lengths some live
    // sources report (~10.6 days in microseconds).
    //
    // Known limitation: some streaming sources (YouTube via browser MPRIS
    // bridge) report length=position while playing and only reflush the
    // real total on pause. The displayed length will be inaccurate until
    // the user pauses once. There's no in-shell fix for that — the source
    // genuinely lies.
    readonly property real trackLen: {
        if (!media || !media.player) return 0;
        const n = media.player.length;
        return (n > 0 && n < 922337203685) ? n : 0;
    }
    // currentPos: imperative — MprisPlayer.position has no per-frame
    // notify, so we poll via FrameAnimation while playing + sync on signals.
    property real currentPos: 0

    function _syncPos() {
        if (!media || !media.player) { currentPos = 0; return; }
        if (seekSlider.dragging) return;
        currentPos = media.player.position;
    }

    Component.onCompleted: _syncPos()
    onActiveChanged: if (active) _syncPos()

    FrameAnimation {
        running: root.media.isPlaying && root.active
        onTriggered: root._syncPos()
    }

    Connections {
        target: root.media.player
        enabled: root.active
        function onPositionChanged()      { root._syncPos(); }
        function onPlaybackStateChanged() { root._syncPos(); }
    }

    Connections {
        target: root.media
        enabled: root.active
        function onPlayerChanged() { root._syncPos(); }
    }

    // Album art
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Theme.mediaAlbumSize
        Layout.preferredHeight: Theme.mediaAlbumSize
        radius: Theme.radiusMedium
        color: Theme.bgHover
        clip: true
        layer.enabled: true

        OptImage {
            id: albumArt
            anchors.fill: parent
            source: root.media.player && root.media.player.trackArtUrl ? root.media.player.trackArtUrl : ""
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !albumArt.visible
            text: Theme.iconPlay
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeHero
            color: Theme.fgDim
            opacity: Theme.opacityDim
        }
    }

    // Track title
    Text {
        Layout.fillWidth: true
        text: root.media.title || "Unknown Title"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.Medium
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    // Artist
    Text {
        Layout.fillWidth: true
        Layout.topMargin: -6
        text: root.media.artist || "Unknown Artist"
        color: Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    // Album
    Text {
        Layout.fillWidth: true
        Layout.topMargin: -6
        visible: root.media.player && root.media.player.trackAlbum !== ""
        text: root.media.player ? (root.media.player.trackAlbum || "") : ""
        color: Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.italic: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        opacity: Theme.opacityBody
    }

    // Seek bar
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingTiny

        SliderTrack {
            id: seekSlider
            Layout.fillWidth: true
            visible: !root.media.isLive
            value: root.trackLen > 0
                ? Math.max(0, Math.min(1, root.currentPos / root.trackLen)) : 0
            accentColor: Theme.accent
            trackHeight: Theme.sliderTrackHeight
            knobSize: Theme.sliderKnobSize
            step: Theme.volumeStep
            onMoved: function(newValue) {
                if (root.media.player && root.media.player.canSeek && root.trackLen > 0) {
                    root.media.player.position = newValue * root.trackLen;
                    root.currentPos = newValue * root.trackLen;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                visible: !root.media.isLive
                text: root.media.formatTime(root.currentPos)
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTiny
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: root.media.isLive
                text: "LIVE"
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTiny
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Item { Layout.fillWidth: true; visible: root.media.isLive }
            Text {
                visible: !root.media.isLive
                text: root.media.formatTime(root.trackLen)
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTiny
            }
        }
    }

    // Transport row: shuffle | prev / play / next | loop
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Theme.spacingMedium

        IconButton {
            icon: Theme.iconShuffle
            size: Theme.iconSize
            visible: root.media.player && root.media.player.shuffleSupported
            normalColor: root.media.player && root.media.player.shuffle ? Theme.accent : Theme.fg
            onClicked: if (root.media.player) root.media.player.shuffle = !root.media.player.shuffle
        }

        MediaControls {
            player: root.media.player
            spacing: 20
            playSize: Theme.iconSize + 4
        }

        IconButton {
            size: Theme.iconSize
            visible: root.media.player && root.media.player.loopSupported
            readonly property int _loop: root.media.player ? root.media.player.loopState : 0
            icon: _loop === MprisLoopState.Track ? Theme.iconLoopOne
                : _loop === MprisLoopState.Playlist ? Theme.iconLoopAll
                : Theme.iconLoopOff
            normalColor: _loop !== MprisLoopState.None ? Theme.accent : Theme.fg
            onClicked: {
                if (!root.media.player) return;
                const next = (root.media.player.loopState + 1) % 3;
                root.media.player.loopState = next;
            }
        }
    }

    // Volume slider — speaker icon (mute toggle) + slider + %
    RowLayout {
        id: mediaVolumeRow
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: root.media.player && root.media.player.volumeSupported
        spacing: Theme.spacingSmall

        readonly property real _vol: root.media.player ? root.media.player.volume : 0
        readonly property bool _muted: _vol < 0.001
        // Restored when the user un-mutes — MPRIS players don't
        // expose a separate mute, so we have to remember what
        // volume to bounce back to.
        property real _preMuteVol: 0.5

        IconButton {
            size: Theme.iconSize
            icon: mediaVolumeRow._muted ? Theme.iconVolMuted
                : mediaVolumeRow._vol < 0.3 ? Theme.iconVolLow
                : mediaVolumeRow._vol < 0.7 ? Theme.iconVolMid
                : Theme.iconVolHigh
            normalColor: mediaVolumeRow._muted ? Theme.red : Theme.fg
            onClicked: {
                if (!root.media.player) return;
                if (mediaVolumeRow._muted) {
                    root.media.player.volume = mediaVolumeRow._preMuteVol;
                } else {
                    mediaVolumeRow._preMuteVol = root.media.player.volume;
                    root.media.player.volume = 0;
                }
            }
        }

        SliderTrack {
            Layout.fillWidth: true
            value: mediaVolumeRow._vol
            accentColor: Theme.accent
            trackHeight: Theme.sliderTrackHeight
            knobSize: Theme.sliderKnobSize
            step: Theme.volumeStep
            onMoved: function(newValue) {
                if (root.media.player) root.media.player.volume = newValue;
            }
        }

        Text {
            Layout.preferredWidth: 32
            horizontalAlignment: Text.AlignRight
            text: Math.round(mediaVolumeRow._vol * 100) + "%"
            color: Theme.fgDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
        }
    }

    // Player picker — chips for switching between active MPRIS players.
    // Only visible when more than one player is alive. Tapping a chip
    // pins Media to that player; an extra "Auto" chip restores the
    // play-priority logic.
    Flow {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: Theme.spacingTiny
        visible: Mpris.players.values.length > 1

        Repeater {
            model: Mpris.players.values
            SkewPill {
                required property var modelData
                readonly property bool isActive: modelData === root.media.player
                text: modelData.identity || modelData.dbusName || "?"
                fillColor: isActive ? Theme.withAlpha(Theme.accent, 0.20) : "transparent"
                strokeColor: isActive ? Theme.accent : Theme.outlineVariant
                textColor: isActive ? Theme.accent : Theme.fg
                fontSize: Theme.fontSizeTiny

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.media.pinPlayer(parent.modelData)
                }
            }
        }
    }
}
