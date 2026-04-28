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

    // Pick the first active player, prefer one that's playing.
    // Pinning (via the popup's player-picker chip) overrides auto-pick and
    // is cleared when the pinned player goes away.
    property var player: null
    property var pinnedPlayer: null
    property bool isPlaying: player ? player.playbackState === MprisPlaybackState.Playing : false
    property string title: player ? (player.trackTitle || "").replace(/[\r\n]/g, "") : ""
    property string artist: player ? (player.trackArtist || "") : ""

    function pinPlayer(p) {
        pinnedPlayer = (pinnedPlayer === p) ? null : p;
        updatePlayer();
    }

    // Players grouped by identity. Browsers expose one MPRIS player per
    // active media tab (all sharing the same identity), so the picker
    // collapses them into one chip-per-source and cycles within a group
    // on repeated clicks.
    readonly property var groupedPlayers: {
        const all = Mpris.players ? Mpris.players.values : [];
        const order = [];
        const byKey = ({});
        for (let i = 0; i < all.length; i++) {
            const p = all[i];
            const key = p.identity || p.dbusName || "?";
            if (!byKey[key]) {
                byKey[key] = { identity: key, players: [] };
                order.push(byKey[key]);
            }
            byKey[key].players.push(p);
        }
        return order;
    }

    // Click semantics for a chip group:
    //   - clicking the active group with >1 player → cycle to the next
    //   - clicking the active group with 1 player → unpin (revert to auto)
    //   - clicking a different group → pin to its first player
    function selectGroup(players) {
        if (!players || players.length === 0) return;
        const idx = players.indexOf(player);
        if (idx >= 0) {
            if (players.length > 1) {
                pinnedPlayer = players[(idx + 1) % players.length];
                updatePlayer();
                return;
            }
            pinPlayer(players[0]);
            return;
        }
        pinnedPlayer = players[0];
        updatePlayer();
    }

    function updatePlayer() {
        if (!Mpris.players || !Mpris.players.values) { player = null; return; }

        const all = Mpris.players.values;

        if (pinnedPlayer && all.indexOf(pinnedPlayer) >= 0) {
            player = pinnedPlayer;
            return;
        }
        if (pinnedPlayer) pinnedPlayer = null;

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

    // Live / streaming detection. Several distinct cases:
    //   1. canSeek=false — pure live HLS where mpv refuses to seek at all.
    //   2. canSeek=true but the stream URL is an HLS .m3u8 / DASH .mpd
    //      manifest — common for Twitch via streamlink and YouTube via
    //      yt-dlp, which pipe a manifest to mpv. mpv permits seeking within
    //      the demuxer's buffered window, so canSeek alone won't fire.
    //   3. Length > 12h — almost nothing legitimate is 12 hours long; a long
    //      Twitch broadcast that has been live for half a day reports its
    //      cumulative session duration via mpris:length and trips this.
    function _isStreamUrl(url) {
        if (!url) return false;
        const u = String(url);
        const lower = u.toLowerCase();
        // HLS / DASH manifests — what streamlink-piped mpv usually sees
        if (lower.indexOf(".m3u8") >= 0) return true;
        if (lower.indexOf(".mpd") >= 0) return true;
        // Twitch live: https://twitch.tv/<channel> with no /videos/ path.
        // Browsers and mpv-via-yt-dlp both produce this xesam:url.
        if (/^https?:\/\/(?:www\.)?twitch\.tv\/[a-z0-9_]+\/?(?:\?.*)?$/i.test(u)) return true;
        // YouTube live page: youtube.com/<channel>/live or /live/<id>
        if (/youtube\.com\/[^?]*\/live(?:\/|\?|$)/i.test(u)) return true;
        return false;
    }
    readonly property bool isLive: {
        if (!player) return false;
        if (!player.canSeek) return true;
        if (player.length > 43200) return true; // > 12h
        const md = player.metadata;
        return !!md && _isStreamUrl(md["xesam:url"]);
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.updatePlayer() }
    }

    // Seed from already-running MPRIS players on construction. Without
    // this a QML hot-reload re-creates Media with player=null and stays
    // empty until the player happens to fire a state change.
    Component.onCompleted: updatePlayer()

    Connections {
        target: root.player
        function onPlaybackStateChanged() { root.updatePlayer() }
        function onTrackTitleChanged() { root.title = (root.player?.trackTitle || "").replace(/[\r\n]/g, "") }
        function onTrackArtistChanged() { root.artist = root.player?.trackArtist || "" }
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall

        MediaControls {
            player: root.player
            skipSize: Theme.iconSize - 2
        }

        // Track info: "Artist - Title" — scrolls on hover if truncated
        InfiniteText {
            id: trackLabel
            Layout.fillWidth: true
            Layout.maximumWidth: 200
            font.pixelSize: Theme.fontSizeSmall
            text: root.artist ? `${root.artist} - ${root.title}` : root.title
            onClicked: root.togglePopup()
        }
    }
}

