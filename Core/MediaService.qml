pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Single source of truth for the active MPRIS player + selection. One instance
// for the whole shell so player-pick and pinning are shared across monitors
// (pinning on one bar must affect all bars), not recomputed/desynced per bar.
// Bar/Media.qml and Bar/MediaPopupContent.qml are views bound to this.
Singleton {
    id: root

    // Pick the first active player, prefer one that's playing. Pinning (via the
    // popup's player-picker chip) overrides auto-pick and is cleared when the
    // pinned player goes away.
    property var player: null
    property var pinnedPlayer: null
    property bool isPlaying: player ? player.playbackState === MprisPlaybackState.Playing : false
    property string title: player ? (player.trackTitle || "").replace(/[\r\n]/g, "") : ""
    property string artist: player ? (player.trackArtist || "") : ""

    function pinPlayer(p) {
        pinnedPlayer = (pinnedPlayer === p) ? null : p;
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

    // Live / streaming detection — see the cases enumerated below.
    function _isStreamUrl(url) {
        if (!url) return false;
        const u = String(url);
        const lower = u.toLowerCase();
        if (lower.indexOf(".m3u8") >= 0) return true;
        if (lower.indexOf(".mpd") >= 0) return true;
        if (/^https?:\/\/(?:www\.)?twitch\.tv\/[a-z0-9_]+\/?(?:\?.*)?$/i.test(u)) return true;
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

    Connections {
        target: root.player
        function onPlaybackStateChanged() { root.updatePlayer() }
        function onTrackTitleChanged() { root.title = (root.player?.trackTitle || "").replace(/[\r\n]/g, "") }
        function onTrackArtistChanged() { root.artist = root.player?.trackArtist || "" }
    }

    Component.onCompleted: updatePlayer()
}
