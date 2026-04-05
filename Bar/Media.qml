import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.Config
import qs.Widgets

Item {
    id: root

    readonly property bool hasMedia: player !== null && title !== ""
    implicitWidth: hasMedia ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight
    visible: hasMedia

    component MediaControls: RowLayout {
        property int skipSize: Theme.iconSize
        property int playSize: Theme.iconSize
        property color controlColor: Theme.fg

        IconButton {
            icon: Theme.iconPrev
            size: parent.skipSize
            normalColor: parent.controlColor
            visible: root.player && root.player.canGoPrevious
            onClicked: root.player.previous()
        }
        IconButton {
            icon: root.isPlaying ? Theme.iconPause : Theme.iconPlay
            size: parent.playSize
            normalColor: parent.controlColor
            onClicked: root.isPlaying ? root.player.pause() : root.player.play()
        }
        IconButton {
            icon: Theme.iconNext
            size: parent.skipSize
            normalColor: parent.controlColor
            visible: root.player && root.player.canGoNext
            onClicked: root.player.next()
        }
    }

    // Expose popup state for StatusBar click-catcher integration
    property bool popupVisible: mediaPopup.isOpen

    function dismissPopup() {
        mediaPopup.close();
    }

    // Pick the first active player, prefer one that's playing
    property var player: null
    property bool isPlaying: player ? player.playbackState === MprisPlaybackState.Playing : false
    property string title: player ? (player.trackTitle || "").replace(/[\r\n]/g, "") : ""
    property string artist: player ? (player.trackArtist || "") : ""

    function updatePlayer() {
        if (!Mpris.players || !Mpris.players.values) { player = null; return; }

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
        player = playing || fallback;
    }

    // Format seconds to mm:ss (or h:mm:ss). Live streams get "LIVE".
    readonly property real maxReasonableLength: 86400 // 24 hours

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0 || seconds > maxReasonableLength) return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = Math.floor(seconds % 60);
        const pad = s < 10 ? "0" : "";
        if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + pad + s;
        return m + ":" + pad + s;
    }

    readonly property bool isLive: player && player.length > maxReasonableLength

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.updatePlayer() }
    }

    Connections {
        target: root.player
        function onPlaybackStateChanged() { root.updatePlayer() }
        function onTrackTitleChanged() { root.title = (root.player?.trackTitle || "").replace(/[\r\n]/g, "") }
        function onTrackArtistChanged() { root.artist = root.player?.trackArtist || "" }
    }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall

        MediaControls {
            skipSize: Theme.iconSize - 2
            controlColor: Theme.fgDim
        }

        // Track info: "Artist - Title" (truncated) — click to toggle popup
        HoverText {
            id: trackLabel
            Layout.maximumWidth: 200
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            text: root.artist ? root.artist + " - " + root.title : root.title
            onClicked: {
                if (mediaPopup.isOpen)
                    mediaPopup.close();
                else
                    mediaPopup.open();
            }
        }
    }

    // ── Expanded media player popup ──────────────────────
    AnimatedPopup {
        id: mediaPopup

        readonly property real popupWidth: 320
        readonly property real artSize: 160

        // Position is read reactively via FrameAnimation when playing
        property real currentPos: root.player ? root.player.position : 0
        property real trackLen: root.player ? root.player.length : 0

        fullHeight: popupContent.implicitHeight + Theme.popupPadding * 2
        implicitWidth: popupWidth
        skewType: "right"

        anchor.item: trackLabel
        anchor.rect.x: -(popupWidth / 2 - trackLabel.width / 2)

        // Reactively update position every frame while playing and popup is open
        FrameAnimation {
            running: root.isPlaying && mediaPopup.isOpen
            onTriggered: {
                if (root.player && !seekSlider.dragging)
                    root.player.positionChanged();
            }
        }

        // Re-read position properties when they change
        Connections {
            target: root.player
            enabled: mediaPopup.isOpen
            function onPositionChanged() {
                if (!seekSlider.dragging)
                    mediaPopup.currentPos = root.player ? root.player.position : 0;
            }
            function onLengthChanged() {
                mediaPopup.trackLen = root.player ? root.player.length : 0;
            }
        }

        ColumnLayout {
            id: popupContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
                anchors.margins: Theme.popupPadding
                spacing: Theme.spacingMedium

                // ── Album art ────────────────────────────
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: mediaPopup.artSize
                    Layout.preferredHeight: mediaPopup.artSize
                    radius: Theme.radiusMedium
                    color: Theme.bgHover
                    clip: true
                    // layer.enabled makes clip respect border radius
                    layer.enabled: true

                    OptImage {
                        id: albumArt
                        anchors.fill: parent
                        source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                        visible: status === Image.Ready
                    }

                    // Placeholder when no art
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

                // ── Track title ──────────────────────────
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    text: root.title || "Unknown Title"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                component MediaSubtext: Text {
                    Layout.fillWidth: true
                    Layout.topMargin: -6
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                // ── Artist name ──────────────────────────
                MediaSubtext { text: root.artist || "Unknown Artist" }

                // ── Album name ───────────────────────────
                MediaSubtext {
                    visible: root.player && root.player.trackAlbum !== ""
                    text: root.player ? (root.player.trackAlbum || "") : ""
                    font.italic: true
                    opacity: Theme.opacityBody
                }

                // ── Seek bar ─────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingTiny

                    SliderTrack {
                        id: seekSlider
                        Layout.fillWidth: true
                        visible: !root.isLive
                        value: mediaPopup.trackLen > 0 ? Math.max(0, Math.min(1, mediaPopup.currentPos / mediaPopup.trackLen)) : 0
                        accentColor: Theme.accent
                        trackHeight: 4
                        knobSize: 12
                        step: Theme.volumeStep

                        onMoved: function(newValue) {
                            if (root.player && root.player.canSeek && mediaPopup.trackLen > 0) {
                                root.player.position = newValue * mediaPopup.trackLen;
                                mediaPopup.currentPos = newValue * mediaPopup.trackLen;
                            }
                        }
                    }

                    // Time labels
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            visible: !root.isLive
                            text: root.formatTime(mediaPopup.currentPos)
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: root.isLive
                            text: "LIVE"
                            color: Theme.red
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item { Layout.fillWidth: true; visible: root.isLive }

                        Text {
                            visible: !root.isLive
                            text: root.formatTime(mediaPopup.trackLen)
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                        }
                    }
                }

                // ── Transport controls ───────────────────
                MediaControls {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 20
                    playSize: Theme.iconSize + 4
                }
            }
        }
    }

