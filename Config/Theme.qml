pragma Singleton

import QtQuick
import Quickshell
import Qs.VibrantColor

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
            cyan:    "#7dcfff",
            secondary: "#9aa5ce",
            tertiary:  "#bb9af7",
            primaryContainer:   "#24283b",
            secondaryContainer: "#1f2335",
            surfaceContainer:   "#1f2233",
            surfaceBright:      "#292e42",
            accentFg: "#1a1b26",
            outline:  "#3b4261",
            outlineVariant: "#2b3049"
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
            cyan:    "#89dceb",
            secondary: "#a6adc8",
            tertiary:  "#cba6f7",
            primaryContainer:   "#27273a",
            secondaryContainer: "#232338",
            surfaceContainer:   "#232336",
            surfaceBright:      "#2e2e44",
            accentFg: "#1e1e2e",
            outline:  "#45475a",
            outlineVariant: "#363849"
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
            cyan:    "#8ec07c",
            secondary: "#bdae93",
            tertiary:  "#d3869b",
            primaryContainer:   "#3c3836",
            secondaryContainer: "#32302f",
            surfaceContainer:   "#32302f",
            surfaceBright:      "#3c3836",
            accentFg: "#282828",
            outline:  "#504945",
            outlineVariant: "#3c3836"
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
            cyan:    "#8fbcbb",
            secondary: "#81a1c1",
            tertiary:  "#b48ead",
            primaryContainer:   "#3b4252",
            secondaryContainer: "#353c4a",
            surfaceContainer:   "#353c4a",
            surfaceBright:      "#434c5e",
            accentFg: "#2e3440",
            outline:  "#4c566a",
            outlineVariant: "#3b4252"
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
            cyan:    "#8be9fd",
            secondary: "#6272a4",
            tertiary:  "#ff79c6",
            primaryContainer:   "#343746",
            secondaryContainer: "#2d2f3e",
            surfaceContainer:   "#2d2f3e",
            surfaceBright:      "#383a4c",
            accentFg: "#282a36",
            outline:  "#44475a",
            outlineVariant: "#363949"
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
            cyan:    "#31748f",
            secondary: "#908caa",
            tertiary:  "#ea9a97",
            primaryContainer:   "#26233a",
            secondaryContainer: "#201e30",
            surfaceContainer:   "#1f1d2e",
            surfaceBright:      "#2a2839",
            accentFg: "#191724",
            outline:  "#524f67",
            outlineVariant: "#3a384a"
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
            cyan:    "#83c092",
            secondary: "#7fbbb3",
            tertiary:  "#d699b6",
            primaryContainer:   "#374145",
            secondaryContainer: "#323c40",
            surfaceContainer:   "#323c40",
            surfaceBright:      "#3d484d",
            accentFg: "#2d353b",
            outline:  "#4f585e",
            outlineVariant: "#3d484d"
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
            cyan:    "#04a5e5",
            secondary: "#7287fd",
            tertiary:  "#8839ef",
            primaryContainer:   "#dce0e8",
            secondaryContainer: "#e2e4ec",
            surfaceContainer:   "#e6e9ef",
            surfaceBright:      "#dce0e8",
            accentFg: "#ffffff",
            outline:  "#8c8fa1",
            outlineVariant: "#bcc0cc"
        }
    })

    readonly property string wallpaperThemeName: "Auto"
    readonly property var paletteNames: [wallpaperThemeName].concat(Object.keys(palettes))
    readonly property url _wallpaperUrl: UserSettings.wallpaperPath ? Qt.resolvedUrl(UserSettings.wallpaperPath) : ""

    function applyPalette(name) {
        if (name === wallpaperThemeName) {
            if (_vibrantColor.source.toString() === _wallpaperUrl.toString() && _vibrantColor.hue >= 0) {
                // Same wallpaper, already extracted — just reapply with current strategy
                _applyWallpaperHue(_vibrantColor.hue);
            } else {
                _vibrantColor.source = _wallpaperUrl;
            }
            return;
        }
        const p = palettes[name];
        if (!p) return;
        _applyColors(p);
    }

    function _applyColors(p) {
        bg = p.bg; bgSolid = p.bgSolid;
        fg = p.fg; fgDim = p.fgDim;
        accent = p.accent;
        red = p.red; green = p.green;
        yellow = p.yellow; cyan = p.cyan;
        const light = !!p.light;
        bgHover      = light ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08);
        border       = light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06);
        overlay      = light ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.06);
        overlayHover = light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.12);
        backdrop     = light ? Qt.rgba(0, 0, 0, 0.30) : Qt.rgba(0, 0, 0, 0.55);
        // MD3 extended — use palette values or derive from existing colors
        secondary          = p.secondary          ?? Qt.lighter(p.fgDim, 1.3);
        tertiary           = p.tertiary           ?? p.cyan;
        primaryContainer   = p.primaryContainer   ?? withAlpha(p.accent, 0.12);
        secondaryContainer = p.secondaryContainer ?? Qt.darker(p.bgSolid, 0.9);
        surfaceContainer   = p.surfaceContainer   ?? Qt.lighter(p.bgSolid, 1.15);
        surfaceBright      = p.surfaceBright      ?? Qt.lighter(p.bgSolid, 1.30);
        accentFg           = p.accentFg           ?? (light ? "#ffffff" : p.bgSolid);
        outline            = p.outline            ?? p.fgDim;
        outlineVariant     = p.outlineVariant     ?? Qt.darker(p.fgDim, 1.5);
    }

    // ── Wallpaper auto-theming ──────────────────────────
    VibrantColor {
        id: _vibrantColor

        onHueChanged: {
            if (UserSettings.themeName === root.wallpaperThemeName)
                root._applyWallpaperHue(hue);
        }
    }

    // React to settings changes that affect theming
    Connections {
        target: UserSettings
        function onWallpaperPathChanged() {
            if (UserSettings.themeName === root.wallpaperThemeName && root._wallpaperUrl != "")
                _vibrantColor.source = root._wallpaperUrl;
        }
        function onThemeNameChanged() {
            if (UserSettings.themeName)
                root.applyPalette(UserSettings.themeName);
        }
        function onWallpaperStrategyChanged() {
            if (UserSettings.themeName === root.wallpaperThemeName && _vibrantColor.hue >= 0)
                root._applyWallpaperHue(_vibrantColor.hue);
        }
    }

    // ── Wallpaper strategies ────────────────────────────
    // Each strategy is a parameter table of [hueKey, saturation, value] tuples.
    // hueKey is "h" (seed), "h2" (h + h2Offset), "h3" (h + h3Offset), or a
    // literal number (fixed hue; use 0 with sat 0 for neutral gray).
    readonly property var _strategyParams: ({
        // Tonal: tinted surfaces, balanced chroma (like Material TonalSpot)
        "Tonal": { h2Offset: 0.17, h3Offset: 0.33, bg: [0.10, 0.10, 0.14, 0.85], colors: {
            bgSolid: ["h", 0.15, 0.12],
            fg: ["h", 0.05, 0.90], fgDim: ["h", 0.08, 0.45],
            accent: ["h", 0.60, 0.85],
            red: [0.98, 0.65, 0.90], green: [0.35, 0.55, 0.75],
            yellow: [0.11, 0.60, 0.88], cyan: [0.52, 0.55, 0.85],
            secondary: ["h2", 0.35, 0.80], tertiary: ["h3", 0.45, 0.80],
            primaryContainer: ["h", 0.20, 0.16], secondaryContainer: ["h2", 0.12, 0.14],
            surfaceContainer: ["h", 0.08, 0.14], surfaceBright: ["h", 0.08, 0.20],
            accentFg: ["h", 0.15, 0.12],
            outline: ["h", 0.10, 0.35], outlineVariant: ["h", 0.08, 0.22]
        }},
        // Vibrant: high chroma, bold tinted surfaces, hue-rotated accent
        "Vibrant": { h2Offset: 0.86, h3Offset: 0.33, bg: [0.10, 0.10, 0.14, 0.85], colors: {
            bgSolid: ["h", 0.25, 0.13],
            fg: ["h", 0.08, 0.92], fgDim: ["h", 0.12, 0.50],
            accent: ["h2", 0.75, 0.90],
            red: [0.98, 0.75, 0.92], green: [0.35, 0.65, 0.80],
            yellow: [0.11, 0.70, 0.92], cyan: [0.52, 0.65, 0.88],
            secondary: ["h", 0.45, 0.85], tertiary: ["h3", 0.55, 0.85],
            primaryContainer: ["h2", 0.30, 0.18], secondaryContainer: ["h", 0.18, 0.15],
            surfaceContainer: ["h", 0.12, 0.15], surfaceBright: ["h", 0.15, 0.22],
            accentFg: ["h2", 0.25, 0.13],
            outline: ["h", 0.15, 0.40], outlineVariant: ["h", 0.10, 0.25]
        }},
        // Neutral: accent from seed, pure gray surfaces
        "Neutral": { h2Offset: 0.17, h3Offset: 0.33, bg: [0.10, 0.10, 0.12, 0.85], colors: {
            bgSolid: [0, 0, 0.11],
            fg: [0, 0, 0.88], fgDim: [0, 0, 0.42],
            accent: ["h", 0.60, 0.85],
            red: [0.98, 0.65, 0.90], green: [0.35, 0.55, 0.75],
            yellow: [0.11, 0.60, 0.88], cyan: [0.52, 0.55, 0.85],
            secondary: ["h2", 0.30, 0.75], tertiary: ["h3", 0.40, 0.75],
            primaryContainer: ["h", 0.15, 0.15], secondaryContainer: [0, 0, 0.13],
            surfaceContainer: [0, 0, 0.13], surfaceBright: [0, 0, 0.18],
            accentFg: [0, 0, 0.11],
            outline: [0, 0, 0.35], outlineVariant: [0, 0, 0.22]
        }},
        // Muted: low chroma tinted surfaces, softer accent
        "Muted": { h2Offset: 0.17, h3Offset: 0.33, bg: [0.10, 0.10, 0.14, 0.85], colors: {
            bgSolid: ["h", 0.10, 0.12],
            fg: ["h", 0.03, 0.85], fgDim: ["h", 0.05, 0.42],
            accent: ["h", 0.35, 0.75],
            red: [0.98, 0.50, 0.80], green: [0.35, 0.40, 0.70],
            yellow: [0.11, 0.45, 0.80], cyan: [0.52, 0.40, 0.75],
            secondary: ["h2", 0.20, 0.65], tertiary: ["h3", 0.25, 0.65],
            primaryContainer: ["h", 0.12, 0.15], secondaryContainer: ["h2", 0.08, 0.13],
            surfaceContainer: ["h", 0.06, 0.14], surfaceBright: ["h", 0.06, 0.19],
            accentFg: ["h", 0.10, 0.12],
            outline: ["h", 0.06, 0.32], outlineVariant: ["h", 0.04, 0.20]
        }}
    })

    readonly property var wallpaperStrategies: Object.keys(_strategyParams).map(n => ({ name: n }))

    function _buildStrategy(name, h) {
        const p = _strategyParams[name] || _strategyParams["Tonal"];
        const hues = { h: h, h2: (h + p.h2Offset) % 1.0, h3: (h + p.h3Offset) % 1.0 };
        const palette = { bg: Qt.rgba(p.bg[0], p.bg[1], p.bg[2], p.bg[3]) };
        for (const key in p.colors) {
            const [hk, s, v] = p.colors[key];
            const hue = typeof hk === "string" ? hues[hk] : hk;
            palette[key] = Qt.hsva(hue, s, v, 1);
        }
        return palette;
    }

    function _strategyIndex() {
        for (let i = 0; i < wallpaperStrategies.length; i++)
            if (wallpaperStrategies[i].name === UserSettings.wallpaperStrategy) return i;
        return 0;
    }

    function _applyWallpaperHue(hue) {
        if (hue < 0) hue = 0.6; // fallback blue
        _applyColors(_buildStrategy(UserSettings.wallpaperStrategy, hue));
    }

    // Apply persisted theme once settings load
    Connections {
        target: UserSettings
        function onSettingsLoaded() {
            if (UserSettings.themeName)
                root.applyPalette(UserSettings.themeName);
        }
    }

    // ── Colors (writable, default to Tokyo Night) ──────
    // IMPORTANT: every writable color below must have a matching `Behavior on X {
    // ColorAnimation { duration: root.animSmooth } }` further down. Missing the
    // Behavior makes palette switches snap instead of crossfade.
    property color bg: Qt.rgba(0.10, 0.10, 0.16, 0.85)
    property color bgSolid: "#1a1b26"
    property color fg: "#c0caf5"
    property color fgDim: "#565f89"
    property color accent: "#7aa2f7"
    property color red: "#f7768e"
    property color green: "#9ece6a"
    property color yellow: "#e0af68"
    property color cyan: "#7dcfff"

    // MD3 extended palette
    property color secondary: "#9aa5ce"
    property color tertiary: "#bb9af7"
    property color primaryContainer: "#24283b"
    property color secondaryContainer: "#1f2335"
    property color surfaceContainer: "#1f2233"
    property color surfaceBright: "#292e42"
    property color accentFg: "#1a1b26"
    property color outline: "#3b4261"
    property color outlineVariant: "#2b3049"

    Behavior on bg { ColorAnimation { duration: root.animSmooth } }
    Behavior on bgSolid { ColorAnimation { duration: root.animSmooth } }
    Behavior on fg { ColorAnimation { duration: root.animSmooth } }
    Behavior on fgDim { ColorAnimation { duration: root.animSmooth } }
    Behavior on accent { ColorAnimation { duration: root.animSmooth } }
    Behavior on red { ColorAnimation { duration: root.animSmooth } }
    Behavior on green { ColorAnimation { duration: root.animSmooth } }
    Behavior on yellow { ColorAnimation { duration: root.animSmooth } }
    Behavior on cyan { ColorAnimation { duration: root.animSmooth } }
    Behavior on secondary { ColorAnimation { duration: root.animSmooth } }
    Behavior on tertiary { ColorAnimation { duration: root.animSmooth } }
    Behavior on primaryContainer { ColorAnimation { duration: root.animSmooth } }
    Behavior on secondaryContainer { ColorAnimation { duration: root.animSmooth } }
    Behavior on surfaceContainer { ColorAnimation { duration: root.animSmooth } }
    Behavior on surfaceBright { ColorAnimation { duration: root.animSmooth } }
    Behavior on accentFg { ColorAnimation { duration: root.animSmooth } }
    Behavior on outline { ColorAnimation { duration: root.animSmooth } }
    Behavior on outlineVariant { ColorAnimation { duration: root.animSmooth } }

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // Accent tints (derived — adapt automatically to palette changes)
    readonly property color accentLight: withAlpha(accent, 0.12)
    readonly property color accentBorder: withAlpha(accent, 0.25)
    readonly property color redLight: withAlpha(red, 0.08)

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

    // Workspace ring segment colors (ordered to avoid adjacent duplicates)
    readonly property var ringColors: [accent, green, yellow, cyan, red, secondary, tertiary]

    // ── Opacity ─────────────────────────────────────────
    readonly property real opacityDim: 0.4
    readonly property real opacityMuted: 0.5
    readonly property real opacitySubtle: 0.6
    readonly property real opacitySecondary: 0.7
    readonly property real opacityBody: 0.85

    // ── Animation ──────────────────────────────────────
    readonly property int animFast: 100       // hover color feedback
    readonly property int animNormal: 150     // state changes (tabs, borders)
    readonly property int animSmooth: 200     // opacity, general movement
    readonly property int animCarousel: 350   // carousel width, position
    readonly property int animSlider: 30      // slider knob tracking
    readonly property int animCrossfade: 500  // wallpaper crossfade
    readonly property int animCursorBlink: 600 // lock screen cursor
    readonly property int animLockFade: 800   // lock screen pulse
    readonly property int animLockShake: 50   // lock screen error shake
    readonly property int animPopIn: 120       // element appearance pop-in
    readonly property int animElastic: 400     // elastic error shake

    // ── Notification timeouts ──────────────────────────
    readonly property int notifShort: 2000      // quick status changes (toggle on/off)
    readonly property int notifNormal: 3000     // standard notifications
    readonly property int notifLong: 5000       // notifications with images
    readonly property int notifDefaultTimeout: 5000  // fallback when sender omits timeout

    // ── Screenshot ─────────────────────────────────────
    readonly property string screenshotPrefix: "/tmp/mcshell-screenshot-"

    // ── Layout ──────────────────────────────────────────
    readonly property int barHeight: 34
    readonly property int barMargin: 3
    readonly property int barSideWidth: 400
    readonly property int barRadius: 10
    readonly property real barDiagSlant: 20
    readonly property int itemSpacing: 14

    // Spacing scale
    readonly property int spacingTiny: 4
    readonly property int spacingSmall: 6
    readonly property int spacingNormal: 8
    readonly property int spacingMedium: 10
    readonly property int spacingLarge: 12

    // Radius scale
    readonly property int radiusTiny: 4
    readonly property int radiusSmall: 6
    readonly property int radiusMedium: 8
    readonly property int radiusLarge: 14

    // Card skew (parallelogram lean factor)
    readonly property real cardSkew: -0.03

    // Popup/panel
    readonly property int popupPadding: 12
    readonly property int barSegmentPadding: 24      // inner padding for bar segments
    readonly property int minCenterWidth: 280        // minimum center segment width
    readonly property int trayMenuMaxHeight: 400     // max tray context menu height
    readonly property int trayMenuPadding: 12        // tray menu content padding
    readonly property int menuRebuildDelay: 16       // ms delay for menu rebuild

    // Dialog/overlay
    readonly property int dialogWidth: 380              // narrow dialogs (polkit, lock)
    readonly property int dialogRadius: 14              // dialog card corner radius
    readonly property int dialogPadding: 24             // inner padding for dialog cards

    // Settings panel rows
    readonly property int settingsRowHeight: 40
    readonly property int settingsRowCompact: 36

    // Audio
    readonly property real volumeStep: 0.02

    // ── Typography ──────────────────────────────────────
    readonly property string fontFamily: "JetBrains Mono"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int fontSizeMini: 10
    readonly property int fontSizeTiny: 11
    readonly property int fontSizeSmall: 13
    readonly property int fontSizeBody: 14
    readonly property int fontSize: 15
    readonly property int fontSizeMedium: 16
    readonly property int fontSizeLarge: 18
    readonly property int fontSizeXLarge: 20
    readonly property int fontSizeHero: 44
    readonly property int fontSizeDisplay: 72
    // Recording/status indicator dot size
    readonly property int indicatorDotSize: 8
    // Notification bell count badge
    readonly property int notifBadgeSize: 14
    readonly property int iconSize: 16
    readonly property int iconSizeSmall: 24
    readonly property int iconSizeMedium: 28
    readonly property int iconSizeLarge: 32
    readonly property int iconSizeXLarge: 48
    readonly property int launcherIconCollapsed: 24
    readonly property int launcherIconExpanded: 48
    readonly property int appIconSmall: 40
    readonly property int appIconLarge: 80

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
    readonly property string iconBluetoothOff: "\u{f00b2}"
    readonly property string iconSettings: "\uf013"
    readonly property string iconTune: "\u{f062e}"  // MDI tune — EQ-style sliders, used for the power profile picker
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
    readonly property string iconMonitor: "\u{f0379}"

    // Toggles
    readonly property string iconDndOn: "\uf1f6"
    readonly property string iconDndOff: "\uf0f3"
    readonly property string iconNightLight: "\ue228"
    readonly property string iconThermometer: "\uf2c9"
    readonly property string iconSunrise: "\uf185"
    readonly property string iconSunset: "\uf186"

    // Weather (Material Design Icons via Nerd Font)
    readonly property string iconSun: "\u{f0599}"           // weather-sunny
    readonly property string iconCloudSun: "\u{f0595}"      // weather-partly-cloudy
    readonly property string iconCloud: "\u{f0590}"         // weather-cloudy
    readonly property string iconCloudRain: "\u{f0597}"     // weather-pouring
    readonly property string iconSnowflake: "\u{f0598}"     // weather-snowy
    readonly property string iconBolt: "\u{f067e}"          // weather-lightning
    readonly property string iconSmog: "\u{f0591}"          // weather-fog
    readonly property string iconWeatherQuestion: "\u{f0f30}" // help-rhombus-outline
    readonly property string iconWeatherError: "\u{f0028}"  // alert-circle
    readonly property string iconLocationPin: "\u{f034e}"   // map-marker
    readonly property string iconGlobe: "\u{f01e7}"         // earth

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
    readonly property string iconShuffle: "\uf074"
    readonly property string iconExpand: "\uf065"

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

    // Popup anchor helper — centers a popup horizontally over its anchor item
    function centerAnchorX(popupWidth, anchorWidth) {
        return -(popupWidth / 2 - anchorWidth / 2);
    }

    // Urgency helper — maps notification urgency to color
    function urgencyColor(urgency) {
        if (urgency === 2) return red;
        if (urgency === 0) return fgDim;
        return accent;
    }

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

    // CPU load color — accent (idle), yellow (busy), red (critical)
    function loadColor(pct) {
        if (pct > 60) return red;
        if (pct > 30) return yellow;
        if (pct > 10) return accent;
        return fgDim;
    }

    // Temperature color — green (cool), yellow (warm), red (hot)
    function tempColor(celsius) {
        if (celsius > 80) return red;
        if (celsius > 40) return yellow;
        return green;
    }

    // Format bytes as human-readable GB
    function toGB(bytes) { return (bytes / 1073741824).toFixed(1); }

    // Format bytes/sec as a speed string. Respects UserSettings.sysInfoNetUnit:
    //   "bytes" — auto-scale B/KB/MB (default)
    //   "kbytes" / "mbytes" — force fixed scale in kilobytes / megabytes
    //   "bits" — auto-scale b/Kb/Mb (×8)
    function formatSpeed(bps) {
        const unit = UserSettings.sysInfoNetUnit;
        if (unit === "bits") {
            const bits = bps * 8;
            if (bits >= 1000000) return (bits / 1000000).toFixed(1) + " Mb/s";
            if (bits >= 1000) return (bits / 1000).toFixed(0) + " Kb/s";
            return bits.toFixed(0) + " b/s";
        }
        if (unit === "kbytes") return (bps / 1024).toFixed(1) + " KB/s";
        if (unit === "mbytes") return (bps / 1048576).toFixed(2) + " MB/s";
        // default: auto-scale bytes
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s";
        if (bps >= 1024) return (bps / 1024).toFixed(0) + " KB/s";
        return bps.toFixed(0) + " B/s";
    }

    // Format celsius as a temperature string. Respects UserSettings.sysInfoTempUnit.
    function formatTemp(celsius) {
        if (UserSettings.sysInfoTempUnit === "F")
            return (celsius * 9 / 5 + 32).toFixed(0) + "\u00B0F";
        return celsius.toFixed(0) + "\u00B0";
    }

    // Format seconds as compact uptime
    function formatUptime(secs) {
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }
}
