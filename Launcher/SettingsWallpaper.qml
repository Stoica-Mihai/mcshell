import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Widgets

// Wallpaper settings card — rotation, fill mode, screen, folder.
SettingsPanel {
    id: root

    // ── Header ──
    readonly property string headerIcon: Theme.iconImage
    readonly property string headerTitle: "Wallpaper"
    readonly property string panelLegend: _editingFolder
        ? Theme.legend(Theme.hintEnter + " save", "Esc cancel")
        : Theme.legend(Theme.hintUpDown, Theme.hintAdjust, Theme.hintEnter + " edit folder", Theme.hintBack)
    readonly property string headerSubtitle: _enabled ? `Rotate ${_options[_intervalIndex].label}` : "Auto rotate off"
    readonly property color headerColor: Theme.accent

    // ── Rotation interval ──
    readonly property var _options: UserSettings.wallpaperRotateOptions
    readonly property int _intervalIndex: {
        const id = UserSettings.wallpaperRotateInterval;
        for (let i = 0; i < _options.length; i++)
            if (_options[i].id === id) return i;
        return 0;
    }
    readonly property bool _enabled: _options[_intervalIndex].ms > 0

    // ── Fill mode ──
    readonly property var _fillModes: UserSettings.wallpaperFillModes
    readonly property int _fillIndex: {
        const id = UserSettings.wallpaperFillMode;
        for (let i = 0; i < _fillModes.length; i++)
            if (_fillModes[i].id === id) return i;
        return 0;
    }

    // ── Rotate screen ──
    readonly property var _rotateScreenNames: UserSettings.screenNames
    readonly property int _rotateScreenIndex: {
        const target = UserSettings.wallpaperRotateScreen;
        if (!target) return 0;
        for (let i = 0; i < _rotateScreenNames.length; i++)
            if (_rotateScreenNames[i] === target) return i;
        return 0;
    }

    // ── Folder editing ──
    property bool _editingFolder: false

    // 0 = interval, 1 = order, 2 = rotate screen, 3 = fill mode, 4 = folder
    itemCount: 5

    function adjustLeft() {
        if (selectedItem === 0) {
            // Interval doesn't wrap — "Off" is a hard boundary
            UserSettings.wallpaperRotateInterval = _options[Math.max(0, _intervalIndex - 1)].id;
            return true;
        }
        if (selectedItem === 1) { orderPicker.cycleLeft(); return true; }
        if (selectedItem === 2) { rotateScreenPicker.cycleLeft(); return true; }
        if (selectedItem === 3) { fillPicker.cycleLeft(); return true; }
        return false;
    }
    function adjustRight() {
        if (selectedItem === 0) {
            UserSettings.wallpaperRotateInterval = _options[Math.min(_options.length - 1, _intervalIndex + 1)].id;
            return true;
        }
        if (selectedItem === 1) { orderPicker.cycleRight(); return true; }
        if (selectedItem === 2) { rotateScreenPicker.cycleRight(); return true; }
        if (selectedItem === 3) { fillPicker.cycleRight(); return true; }
        return false;
    }

    function activateItem() {
        if (selectedItem === 4) {
            _editingFolder = true;
            folderInput.text = UserSettings.wallpaperFolder;
            folderInput.forceActiveFocus();
        }
    }

    // Auto-rotate interval
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

    // Rotation order
    SettingsRow {
        selected: root.active && root.selectedItem === 1
        Layout.preferredHeight: Theme.settingsRowHeight

        Text {
            text: Theme.iconShuffle
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: root._enabled ? Theme.accent : Theme.fgDim
        }
        Text {
            text: "Order"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
        CyclePicker {
            id: orderPicker
            model: ["Shuffle", "Sequential"]
            currentIndex: UserSettings.wallpaperRotateMode === "sequential" ? 1 : 0
            onIndexChanged: idx => {
                UserSettings.wallpaperRotateMode = idx === 0 ? "shuffle" : "sequential";
            }
        }
    }

    // Rotate screen
    SettingsRow {
        selected: root.active && root.selectedItem === 2
        Layout.preferredHeight: Theme.settingsRowHeight

        Text {
            text: Theme.iconMonitor
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: root._enabled ? Theme.accent : Theme.fgDim
        }
        Text {
            text: "Screen"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
        CyclePicker {
            id: rotateScreenPicker
            model: root._rotateScreenNames
            currentIndex: root._rotateScreenIndex
            onIndexChanged: idx => {
                UserSettings.wallpaperRotateScreen = idx === 0 ? "" : root._rotateScreenNames[idx];
            }
        }
    }

    Separator {}

    // Fill mode
    SettingsRow {
        selected: root.active && root.selectedItem === 3
        Layout.preferredHeight: Theme.settingsRowHeight

        Text {
            text: Theme.iconExpand
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.accent
        }
        Text {
            text: "Fill Mode"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fg
            Layout.fillWidth: true
        }
        CyclePicker {
            id: fillPicker
            model: root._fillModes.map(m => m.label)
            currentIndex: root._fillIndex
            onIndexChanged: idx => {
                UserSettings.wallpaperFillMode = root._fillModes[idx].id;
            }
        }
    }

    Separator {}

    // Folder path
    SettingsRow {
        selected: root.active && root.selectedItem === 4
        Layout.preferredHeight: Theme.settingsRowHeight

        Text {
            text: Theme.iconFolder
            font.family: Theme.iconFont
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.accent
        }

        // Normal view: show path
        Text {
            visible: !root._editingFolder
            text: UserSettings.wallpaperFolder || "Not set"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.fgDim
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }

        // Edit view: text input
        Rectangle {
            visible: root._editingFolder
            Layout.fillWidth: true
            height: 24
            radius: Theme.radiusSmall
            color: Theme.overlay
            border.width: 1
            border.color: folderInput.activeFocus ? Theme.accent : Theme.border

            TextInput {
                id: folderInput
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingNormal
                anchors.rightMargin: Theme.spacingNormal
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.fg
                clip: true
                selectByMouse: true

                onAccepted: {
                    UserSettings.wallpaperFolder = text;
                    root._editingFolder = false;
                }

                Keys.onEscapePressed: {
                    root._editingFolder = false;
                }
            }
        }
    }
}
