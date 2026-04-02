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
    readonly property color overlay: Qt.rgba(1, 1, 1, 0.06)
    readonly property color overlayHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color backdrop: Qt.rgba(0, 0, 0, 0.55)

    // ── Animation ──────────────────────────────────────
    readonly property int animFast: 100       // hover color feedback
    readonly property int animNormal: 150     // state changes (tabs, borders)
    readonly property int animSmooth: 200     // opacity, general movement
    readonly property int animCarousel: 350   // carousel width, position

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

    // Battery
    readonly property string iconBattery: "\u{f008e}"
    readonly property string iconBattery10: "\u{f007a}"
    readonly property string iconBattery20: "\u{f007b}"
    readonly property string iconBattery30: "\u{f007c}"
    readonly property string iconBattery40: "\u{f007d}"
    readonly property string iconBattery50: "\u{f007e}"
    readonly property string iconBattery60: "\u{f007f}"
    readonly property string iconBattery70: "\u{f0080}"
    readonly property string iconBattery80: "\u{f0081}"
    readonly property string iconBattery90: "\u{f0082}"
    readonly property string iconBatteryFull: "\u{f0079}"
    readonly property string iconBatteryCharging: "\u{f0084}"
    readonly property string iconBatteryAlert: "\u{f0083}"

    // Fallback
    readonly property string iconMissing: "\uf059"  // question-circle

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

    // Battery helper — returns the right icon for a charge level
    function batteryIcon(pct, charging) {
        if (charging) return iconBatteryCharging;
        if (pct >= 95) return iconBatteryFull;
        if (pct >= 85) return iconBattery90;
        if (pct >= 75) return iconBattery80;
        if (pct >= 65) return iconBattery70;
        if (pct >= 55) return iconBattery60;
        if (pct >= 45) return iconBattery50;
        if (pct >= 35) return iconBattery40;
        if (pct >= 25) return iconBattery30;
        if (pct >= 15) return iconBattery20;
        if (pct >= 5) return iconBattery10;
        return iconBatteryAlert;
    }
}
