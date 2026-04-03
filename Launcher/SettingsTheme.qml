import QtQuick
import QtQuick.Layouts
import qs.Config

// Theme settings card content — palette picker.
SettingsPanel {
    id: root

    // ── Header ──
    readonly property string headerIcon: Theme.iconPalette
    readonly property string headerTitle: "Theme"
    readonly property string panelLegend: Theme.legend(Theme.hintUpDown, Theme.hintEnter + " apply", Theme.hintBack)
    readonly property string headerSubtitle: currentTheme
    readonly property color headerColor: Theme.accent

    readonly property var themeNames: Theme.paletteNames
    readonly property string currentTheme: UserSettings.themeName || "Tokyo Night"

    itemCount: themeNames.length

    function activateItem() {
        const name = themeNames[selectedItem];
        UserSettings.themeName = name;
        Theme.applyPalette(name);
    }

    Repeater {
        id: themeRepeater
        model: root.themeNames

        SettingsRow {
            required property string modelData
            required property int index
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
            Row {
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
