pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // ── Colors ──────────────────────────────────────────
    // Swap this block to change the entire shell's palette.

    // Background
    readonly property color bg: Qt.rgba(0.10, 0.10, 0.16, 0.85)
    readonly property color bgSolid: "#1a1b26"
    readonly property color bgHover: Qt.rgba(1, 1, 1, 0.08)

    // Foreground
    readonly property color fg: "#c0caf5"
    readonly property color fgDim: "#565f89"

    // Accent
    readonly property color accent: "#7aa2f7"

    // Semantic
    readonly property color red: "#f7768e"
    readonly property color green: "#9ece6a"
    readonly property color yellow: "#e0af68"
    readonly property color cyan: "#7dcfff"

    // Surface
    readonly property color border: Qt.rgba(1, 1, 1, 0.06)

    // ── Layout ──────────────────────────────────────────
    readonly property int barHeight: 34
    readonly property int barMargin: 5
    readonly property int barRadius: 10
    readonly property int itemSpacing: 14

    // ── Typography ──────────────────────────────────────
    readonly property string fontFamily: "JetBrains Mono"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int fontSize: 13
    readonly property int fontSizeSmall: 11
    readonly property int iconSize: 16

    // ── Icons (Nerd Font codepoints) ────────────────────
    // Volume
    readonly property string iconVolHigh: "\uf028"
    readonly property string iconVolMid: "\uf027"
    readonly property string iconVolLow: "\uf026"
    readonly property string iconVolMuted: "\uf466"

    // Media
    readonly property string iconPlay: "\uf04b"
    readonly property string iconPause: "\uf04c"
    readonly property string iconPrev: "\uf048"
    readonly property string iconNext: "\uf051"

    // Network
    readonly property string iconWifi: "\uf1eb"
    readonly property string iconNetOff: "\uf467"
    readonly property string iconWifiOff: "\u{f092e}"
    readonly property string iconEthernet: "\u{f09e9}"

    // System
    readonly property string iconBrightness: "\uf185"
    readonly property string iconBluetooth: "\uf294"
    readonly property string iconBluetoothOff: "\u{f00b7}"
    readonly property string iconSettings: "\uf013"
    readonly property string iconSearch: "\uf002"
    readonly property string iconKeyboard: "\uf11c"
    readonly property string iconBell: "\uf0f3"
    readonly property string iconClose: "\uf00d"
    readonly property string iconCheck: "\uf00c"
    readonly property string iconChevronRight: "\uf054"
    readonly property string iconArrowLeft: "\u25C0"
    readonly property string iconArrowRight: "\u25B6"
    readonly property string iconArrowTo: "\u2192"

    // Power
    readonly property string iconLock: "\uf023"
    readonly property string iconLogout: "\uf08b"
    readonly property string iconReboot: "\uf021"
    readonly property string iconShutdown: "\uf011"

    // History / Clipboard
    readonly property string iconTrash: "\uf1f8"
    readonly property string iconClock: "\uf017"
    readonly property string iconBellSlash: "\uf1f6"
    readonly property string iconClipboard: "\uf0ea"
    readonly property string iconImage: "\uf03e"
    readonly property string iconApps: "\uf0e8"

    // Toggles
    readonly property string iconDndOn: "\uf1f6"
    readonly property string iconDndOff: "\uf0f3"
    readonly property string iconNightLight: "\ue228"

    // Wallpaper
    readonly property string iconWallpaper: "\u{f00ab}"
    readonly property string iconFolder: "\uf07b"

    // Volume helper — returns the right icon for a volume level
    function volumeIcon(volume, muted) {
        if (muted) return iconVolMuted;
        if (volume < 0.3) return iconVolLow;
        if (volume < 0.7) return iconVolMid;
        return iconVolHigh;
    }
}
