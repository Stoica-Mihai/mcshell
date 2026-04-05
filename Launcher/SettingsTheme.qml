import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Widgets

// Theme settings card content — palette picker.
SettingsPanel {
    id: root

    // ── Header ──
    readonly property string headerIcon: Theme.iconPalette
    readonly property string headerTitle: "Theme"
    readonly property string panelLegend: Theme.legend(Theme.hintUpDown, isWallpaperTheme ? Theme.hintAdjust : "", Theme.hintEnter + " apply", Theme.hintBack)
    readonly property string headerSubtitle: currentTheme
    readonly property color headerColor: Theme.accent

    readonly property var themeNames: Theme.paletteNames
    readonly property var _strategyNames: Theme.wallpaperStrategies.map(s => s.name)
    readonly property string currentTheme: UserSettings.themeName || "Tokyo Night"
    readonly property bool isWallpaperTheme: currentTheme === Theme.wallpaperThemeName

    itemCount: themeNames.length

    function activateItem() {
        const name = themeNames[selectedItem];
        UserSettings.themeName = name;
        Theme.applyPalette(name);
    }

    function adjustLeft() {
        if (themeNames[selectedItem] !== Theme.wallpaperThemeName || !isWallpaperTheme) return false;
        strategyCycler.cycleLeft();
        return true;
    }
    function adjustRight() {
        if (themeNames[selectedItem] !== Theme.wallpaperThemeName || !isWallpaperTheme) return false;
        strategyCycler.cycleRight();
        return true;
    }

    CyclePicker {
        id: strategyCycler
        visible: false
        model: root._strategyNames
        currentIndex: Theme._strategyIndex()
        onIndexChanged: idx => {
            UserSettings.wallpaperStrategy = Theme.wallpaperStrategies[idx].name;
            Theme.applyPalette(Theme.wallpaperThemeName);
        }
    }

    Repeater {
        id: themeRepeater
        model: root.themeNames

        SelectionRow {
            required property string modelData
            required property int index
            readonly property bool isWallpaper: modelData === Theme.wallpaperThemeName
            selected: root.active && root.selectedItem === index
            Layout.preferredHeight: 32
            label: modelData
            isCurrent: modelData === root.currentTheme

            // Right column: strategy picker or color dots (fixed width for alignment)
            Item {
                Layout.preferredWidth: 120
                Layout.preferredHeight: parent.height

                CyclePicker {
                    anchors.centerIn: parent
                    visible: isWallpaper
                    model: root._strategyNames
                    currentIndex: Theme._strategyIndex()
                    enabled: root.isWallpaperTheme
                }
                Row {
                    anchors.centerIn: parent
                    visible: !isWallpaper
                    spacing: 3
                    Repeater {
                        model: {
                            const p = Theme.palettes[modelData];
                            return p ? [p.accent, p.red, p.green, p.yellow, p.cyan] : [];
                        }
                        Rectangle {
                            required property color modelData
                            width: 8; height: 8; radius: Theme.radiusTiny
                            color: modelData
                        }
                    }
                }
            }
        }
    }
}
