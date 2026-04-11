import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Widgets

// Wallpaper settings card — auto-rotate interval picker with Off.
SettingsPanel {
    id: root

    // ── Header ──
    readonly property string headerIcon: Theme.iconImage
    readonly property string headerTitle: "Wallpaper"
    readonly property string panelLegend: Theme.legend(Theme.hintUpDown, Theme.hintAdjust, Theme.hintBack)
    readonly property string headerSubtitle: _enabled ? `Auto rotate every ${_options[_intervalIndex].label}` : "Auto rotate off"
    readonly property color headerColor: Theme.accent

    // ── Interval mapping ──
    readonly property var _options: UserSettings.wallpaperRotateOptions
    readonly property int _intervalIndex: {
        const id = UserSettings.wallpaperRotateInterval;
        for (let i = 0; i < _options.length; i++)
            if (_options[i].id === id) return i;
        return 0;
    }
    readonly property bool _enabled: _options[_intervalIndex].ms > 0

    itemCount: 1

    function adjustLeft() {
        UserSettings.wallpaperRotateInterval = _options[Math.max(0, _intervalIndex - 1)].id;
        return true;
    }
    function adjustRight() {
        UserSettings.wallpaperRotateInterval = _options[Math.min(_options.length - 1, _intervalIndex + 1)].id;
        return true;
    }

    SettingsRow {
        selected: root.active && root.selectedItem === 0
        Layout.preferredHeight: Theme.settingsRowHeight

        Text {
            text: Theme.iconImage
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: root._enabled ? Theme.accent : Theme.fgDim
        }
        Text {
            text: "Auto Rotate"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
        Text {
            text: root._options[root._intervalIndex].label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
            color: root._enabled ? Theme.accent : Theme.fgDim
        }
    }
}
