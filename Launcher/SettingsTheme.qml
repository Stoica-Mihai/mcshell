import QtQuick
import QtQuick.Layouts
import qs.Config

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
    readonly property string currentTheme: UserSettings.themeName || "Tokyo Night"
    readonly property bool isWallpaperTheme: currentTheme === Theme.wallpaperThemeName

    itemCount: themeNames.length

    function activateItem() {
        const name = themeNames[selectedItem];
        UserSettings.themeName = name;
        Theme.applyPalette(name);
    }

    function adjustLeft() {
        if (themeNames[selectedItem] === Theme.wallpaperThemeName && isWallpaperTheme) {
            const len = Theme.wallpaperStrategies.length;
            UserSettings.wallpaperStrategy = (UserSettings.wallpaperStrategy - 1 + len) % len;
            Theme.applyPalette(Theme.wallpaperThemeName);
            return true;
        }
        return false;
    }

    function adjustRight() {
        if (themeNames[selectedItem] === Theme.wallpaperThemeName && isWallpaperTheme) {
            const len = Theme.wallpaperStrategies.length;
            UserSettings.wallpaperStrategy = (UserSettings.wallpaperStrategy + 1) % len;
            Theme.applyPalette(Theme.wallpaperThemeName);
            return true;
        }
        return false;
    }

    Repeater {
        id: themeRepeater
        model: root.themeNames

        SettingsRow {
            required property string modelData
            required property int index
            readonly property bool isWallpaper: modelData === Theme.wallpaperThemeName
            selected: root.active && root.selectedItem === index
            Layout.preferredHeight: 32

            Text {
                text: modelData === root.currentTheme ? Theme.iconCheck : ""
                font.family: Theme.iconFont
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.green
                Layout.preferredWidth: 14
            }
            Text {
                text: modelData
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: modelData === root.currentTheme ? Theme.accent : Theme.fg
                Layout.fillWidth: true
            }
            // Right column: strategy picker or color dots (fixed width for alignment)
            Item {
                Layout.preferredWidth: 120
                Layout.preferredHeight: parent.height

                Text {
                    anchors.centerIn: parent
                    visible: isWallpaper
                    text: Theme.iconArrowLeft + "  " + Theme.wallpaperStrategies[UserSettings.wallpaperStrategy].name + "  " + Theme.iconArrowRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.isWallpaperTheme ? Theme.accent : Theme.fgDim
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
                            width: 8; height: 8; radius: 4
                            color: modelData
                        }
                    }
                }
            }
        }
    }
}
