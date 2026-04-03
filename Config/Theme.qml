pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // ── Palettes ───────────────────────────────────────
    readonly property var palettes: ({
        "Tokyo Night": {
            bg:      Qt.rgba(0.10, 0.10, 0.16, 0.85),
            bgSolid: "#1a1b26",
            fg:      "#c0caf5",
            fgDim:   "#565f89",
            accent:  "#7aa2f7",
            red:     "#f7768e",
            green:   "#9ece6a",
            yellow:  "#e0af68",
            cyan:    "#7dcfff"
        },
        "Catppuccin Mocha": {
            bg:      Qt.rgba(0.12, 0.12, 0.18, 0.85),
            bgSolid: "#1e1e2e",
            fg:      "#cdd6f4",
            fgDim:   "#6c7086",
            accent:  "#89b4fa",
            red:     "#f38ba8",
            green:   "#a6e3a1",
            yellow:  "#f9e2af",
            cyan:    "#89dceb"
        },
        "Gruvbox Dark": {
            bg:      Qt.rgba(0.16, 0.15, 0.13, 0.85),
            bgSolid: "#282828",
            fg:      "#ebdbb2",
            fgDim:   "#928374",
            accent:  "#83a598",
            red:     "#fb4934",
            green:   "#b8bb26",
            yellow:  "#fabd2f",
            cyan:    "#8ec07c"
        },
        "Nord": {
            bg:      Qt.rgba(0.18, 0.20, 0.25, 0.85),
            bgSolid: "#2e3440",
            fg:      "#eceff4",
            fgDim:   "#4c566a",
            accent:  "#88c0d0",
            red:     "#bf616a",
            green:   "#a3be8c",
            yellow:  "#ebcb8b",
            cyan:    "#8fbcbb"
        },
        "Dracula": {
            bg:      Qt.rgba(0.16, 0.16, 0.21, 0.85),
            bgSolid: "#282a36",
            fg:      "#f8f8f2",
            fgDim:   "#6272a4",
            accent:  "#bd93f9",
            red:     "#ff5555",
            green:   "#50fa7b",
            yellow:  "#f1fa8c",
            cyan:    "#8be9fd"
        },
        "Rosé Pine": {
            bg:      Qt.rgba(0.14, 0.13, 0.18, 0.85),
            bgSolid: "#191724",
            fg:      "#e0def4",
            fgDim:   "#6e6a86",
            accent:  "#c4a7e7",
            red:     "#eb6f92",
            green:   "#9ccfd8",
            yellow:  "#f6c177",
            cyan:    "#31748f"
        },
        "Everforest Dark": {
            bg:      Qt.rgba(0.17, 0.20, 0.17, 0.85),
            bgSolid: "#2d353b",
            fg:      "#d3c6aa",
            fgDim:   "#859289",
            accent:  "#a7c080",
            red:     "#e67e80",
            green:   "#a7c080",
            yellow:  "#dbbc7f",
            cyan:    "#83c092"
        },
        "Catppuccin Latte": {
            light:   true,
            bg:      Qt.rgba(0.94, 0.93, 0.96, 0.92),
            bgSolid: "#eff1f5",
            fg:      "#4c4f69",
            fgDim:   "#9ca0b0",
            accent:  "#1e66f5",
            red:     "#d20f39",
            green:   "#40a02b",
            yellow:  "#df8e1d",
            cyan:    "#04a5e5"
        }
    })

    readonly property var paletteNames: Object.keys(palettes)

    function applyPalette(name) {
        const p = palettes[name];
        if (!p) return;
        bg = p.bg; bgSolid = p.bgSolid;
        fg = p.fg; fgDim = p.fgDim;
        accent = p.accent;
        red = p.red; green = p.green;
        yellow = p.yellow; cyan = p.cyan;
        // Surface colors flip for light themes
        const light = !!p.light;
        bgHover      = light ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08);
        border       = light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06);
        overlay      = light ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.06);
        overlayHover = light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.12);
        backdrop     = light ? Qt.rgba(0, 0, 0, 0.30) : Qt.rgba(0, 0, 0, 0.55);
    }

    // Apply persisted theme once settings load
    Connections {
        target: UserSettings
        function onLoadedChanged() {
            if (UserSettings.loaded && UserSettings.themeName)
                root.applyPalette(UserSettings.themeName);
        }
    }

    // ── Colors (writable, default to Tokyo Night) ──────
    property color bg: Qt.rgba(0.10, 0.10, 0.16, 0.85)
    property color bgSolid: "#1a1b26"
    property color fg: "#c0caf5"
    property color fgDim: "#565f89"
    property color accent: "#7aa2f7"
    property color red: "#f7768e"
    property color green: "#9ece6a"
    property color yellow: "#e0af68"
    property color cyan: "#7dcfff"

    Behavior on bg { ColorAnimation { duration: root.animSmooth } }
    Behavior on bgSolid { ColorAnimation { duration: root.animSmooth } }
    Behavior on fg { ColorAnimation { duration: root.animSmooth } }
    Behavior on fgDim { ColorAnimation { duration: root.animSmooth } }
    Behavior on accent { ColorAnimation { duration: root.animSmooth } }
    Behavior on red { ColorAnimation { duration: root.animSmooth } }
    Behavior on green { ColorAnimation { duration: root.animSmooth } }
    Behavior on yellow { ColorAnimation { duration: root.animSmooth } }
    Behavior on cyan { ColorAnimation { duration: root.animSmooth } }

    // Surface (adapts for light/dark themes)
    property color bgHover: Qt.rgba(1, 1, 1, 0.08)
    property color border: Qt.rgba(1, 1, 1, 0.06)
    property color overlay: Qt.rgba(1, 1, 1, 0.06)
    property color overlayHover: Qt.rgba(1, 1, 1, 0.12)
    property color backdrop: Qt.rgba(0, 0, 0, 0.55)

    Behavior on bgHover { ColorAnimation { duration: root.animSmooth } }
    Behavior on border { ColorAnimation { duration: root.animSmooth } }
    Behavior on overlay { ColorAnimation { duration: root.animSmooth } }
    Behavior on overlayHover { ColorAnimation { duration: root.animSmooth } }
    Behavior on backdrop { ColorAnimation { duration: root.animSmooth } }

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
    readonly property int fontSizeMini: 9
    readonly property int fontSizeTiny: 10
    readonly property int fontSizeSmall: 11
    readonly property int fontSize: 13
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeXLarge: 18
    readonly property int iconSize: 16
    readonly property int iconSizeSmall: 24
    readonly property int iconSizeMedium: 28
    readonly property int iconSizeLarge: 32
    readonly property int iconSizeXLarge: 48

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
    readonly property string iconThermometer: "\uf2c9"
    readonly property string iconSunrise: "\uf185"
    readonly property string iconSunset: "\uf186"

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

    // Theme
    readonly property string iconPalette: "\u{f03d8}"

    // Fallback
    readonly property string iconMissing: "\uf059"  // question-circle

    // Wallpaper
    readonly property string iconWallpaper: "\u{f00ab}"
    readonly property string iconFolder: "\uf07b"

    // ── Legend hint building blocks ─────────────────────
    readonly property string hintUpDown: "\u2191 \u2193 Items"
    readonly property string hintLeftRight: "\u2190 \u2192"
    readonly property string hintNav: hintLeftRight + " Navigate"
    readonly property string hintAdjust: hintLeftRight + " Adjust"
    readonly property string hintCategory: hintLeftRight + " Category"
    readonly property string hintEnter: "Enter"
    readonly property string hintEsc: "ESC"
    readonly property string hintBack: hintEsc + " back"
    readonly property string hintClose: hintEsc + " close"

    readonly property string separator: " • "
    function legend(...parts) { return parts.join("  |  "); }

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
