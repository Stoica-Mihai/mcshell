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
    readonly property string panelLegend: {
        const onBlur = selectedItem === 0;
        const verb = onBlur ? "" : Theme.hintEnter + " apply";
        const adjust = onBlur || isWallpaperTheme ? Theme.hintAdjust : "";
        return Theme.legend(Theme.hintUpDown, adjust, verb, Theme.hintBack);
    }
    readonly property string headerSubtitle: currentTheme
    readonly property color headerColor: Theme.accent

    readonly property var themeNames: Theme.paletteNames
    readonly property var _strategyNames: Theme.wallpaperStrategies.map(s => s.name)
    readonly property string currentTheme: UserSettings.themeName || "Tokyo Night"
    readonly property bool isWallpaperTheme: currentTheme === Theme.wallpaperThemeName

    // Item 0 = blur toggle, items 1..N = palette names
    itemCount: 1 + themeNames.length

    function activateItem() {
        if (selectedItem === 0) return;
        const name = themeNames[selectedItem - 1];
        UserSettings.themeName = name;
        Theme.applyPalette(name);
    }

    function _flipBlur() {
        UserSettings.blurEnabled = !UserSettings.blurEnabled;
        return true;
    }

    function adjustLeft() {
        if (selectedItem === 0) return _flipBlur();
        if (themeNames[selectedItem - 1] !== Theme.wallpaperThemeName || !isWallpaperTheme) return false;
        strategyCycler.cycleLeft();
        return true;
    }
    function adjustRight() {
        if (selectedItem === 0) return _flipBlur();
        if (themeNames[selectedItem - 1] !== Theme.wallpaperThemeName || !isWallpaperTheme) return false;
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

    // ── Item 0: Blur toggle ──
    // Use SelectionRow so it matches the theme rows below (checkmark column +
    // label filling middle + fixed-width right column for the SkewToggle).
    SelectionRow {
        selected: root.active && root.selectedItem === 0
        label: "Blur surfaces"
        isCurrent: UserSettings.blurEnabled

        Item {
            Layout.preferredWidth: 120
            Layout.preferredHeight: parent.height
            SkewToggle {
                anchors.centerIn: parent
                state: UserSettings.blurEnabled ? 1 : 0
            }
        }
    }

    Repeater {
        id: themeRepeater
        model: root.themeNames

        SelectionRow {
            required property string modelData
            required property int index
            readonly property bool isWallpaper: modelData === Theme.wallpaperThemeName
            selected: root.active && root.selectedItem === (index + 1)
            Layout.preferredHeight: 32
            label: modelData
            isCurrent: modelData === root.currentTheme

            // Right column: strategy picker or color dots (fixed width for alignment)
            Item {
                Layout.preferredWidth: 120
                Layout.preferredHeight: parent.height

                CyclePicker {
                    anchors.centerIn: parent
                    pillValue: true
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
