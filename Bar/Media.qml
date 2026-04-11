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

    // Expose popup state for StatusBar click-catcher integration
    property bool popupVisible: false

    signal togglePopup()
    signal dismissPopup()

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
        const ss = String(s).padStart(2, "0");
        if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${ss}`;
        return `${m}:${ss}`;
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
            player: root.player
            skipSize: Theme.iconSize - 2
            controlColor: Theme.fgDim
        }

        // Track info: "Artist - Title" — scrolls on hover if truncated
        InfiniteText {
            id: trackLabel
            Layout.maximumWidth: 200
            font.pixelSize: Theme.fontSizeSmall
            text: root.artist ? `${root.artist} - ${root.title}` : root.title
            onClicked: root.togglePopup()
        }
    }
}

