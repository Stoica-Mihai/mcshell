import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Widgets
import qs.Launcher

FocusScope {
    id: root

    // True while the hosting BarPopupWindow is actually open — used to gate
    // the preview SystemClock so it doesn't tick while the popup is closed.
    property bool windowOpen: false

    readonly property real fullHeight: content.implicitHeight + Theme.spacingNormal * 2

    readonly property alias selectedRow: nav.selectedRow
    readonly property alias rowCount: nav.rowCount
    readonly property alias nav: nav

    readonly property date _exampleDate: new Date(2024, 0, 15)

    readonly property var _dateFormatPatterns: [
        "ddd d MMM yyyy",
        "d MMM yyyy",
        "d MMMM yyyy",
        "dddd, d MMMM",
        "yyyy-MM-dd",
        "d.M.yyyy",
        "d/M/yyyy"
    ]
    readonly property var _dateFormatLabels: _dateFormatPatterns.map(
        p => _exampleDate.toLocaleDateString(Qt.locale(), p))

    // Each row owns its entire configuration — label, section header,
    // the visible labels (model), the stored values (parallel array), and
    // the name of the UserSettings property to read/write.
    //
    // `values[i]` is persisted; `model[i]` is shown. The indices match.
    readonly property var _rows: [
        {
            kind: "cycle",
            section: "Time",
            label: "Time format",
            setting: "clockTimeFormat",
            values: ["24h", "12h"],
            model:  ["24 hour", "12 hour"]
        },
        {
            kind: "toggle",
            section: "",
            label: "Show seconds",
            setting: "clockShowSeconds"
        },
        {
            kind: "cycle",
            section: "",
            label: "Date format",
            setting: "clockDateFormat",
            values: _dateFormatPatterns,
            model:  _dateFormatLabels
        },
        {
            kind: "cycle",
            section: "Calendar",
            label: "Week starts on",
            setting: "weekStartsOnMonday",
            values: [true, false],
            model:  ["Monday", "Sunday"]
        }
    ]

    KeyboardRowNav {
        id: nav
        rows: root._rows
    }

    // Preview ticker — gated on window visibility so it doesn't run perpetually.
    SystemClock {
        id: previewClock
        precision: SystemClock.Seconds
        enabled: root.windowOpen
    }

    anchors.fill: parent
    focus: true

    onWindowOpenChanged: if (windowOpen) { nav.reset(); forceActiveFocus(); }

    Keys.onUpPressed:     nav.navigate(-1)
    Keys.onDownPressed:   nav.navigate(1)
    Keys.onLeftPressed:   nav.adjust(-1)
    Keys.onRightPressed:  nav.adjust(1)
    Keys.onReturnPressed: nav.activate()
    Keys.onSpacePressed:  nav.activate()

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingNormal
        spacing: Theme.spacingSmall

        // Preview
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: previewClock.date.toLocaleTimeString(Qt.locale(), UserSettings.clockTimeFormatString)
            font.family: Theme.fontFamily
            font.pixelSize: 32
            font.weight: Font.Medium
            color: Theme.fg
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Theme.spacingSmall
            text: previewClock.date.toLocaleDateString(Qt.locale(), UserSettings.clockDateFormat)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fgDim
        }

        Separator {}

        Repeater {
            id: rowRepeater
            model: root._rows

            ColumnLayout {
                id: rowItem
                required property var modelData
                required property int index
                spacing: Theme.spacingTiny
                Layout.fillWidth: true

                readonly property alias cycler: rowCycler

                Text {
                    visible: rowItem.modelData.section !== ""
                    Layout.leftMargin: Theme.spacingMedium
                    Layout.topMargin: Theme.spacingSmall
                    text: rowItem.modelData.section
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMini
                    color: Theme.fgDim
                    opacity: Theme.opacitySecondary
                }

                SettingsRow {
                    Layout.preferredHeight: Theme.settingsRowCompact
                    selected: root.selectedRow === rowItem.index

                    Text {
                        text: rowItem.modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fg
                        Layout.fillWidth: true
                    }

                    CyclePicker {
                        id: rowCycler
                        pillValue: true
                        visible: rowItem.modelData.kind === "cycle"
                        model: rowItem.modelData.kind === "cycle" ? rowItem.modelData.model : []
                        currentIndex: rowItem.modelData.kind === "cycle"
                            ? Math.max(0, rowItem.modelData.values.indexOf(UserSettings[rowItem.modelData.setting]))
                            : 0
                        onIndexChanged: idx => {
                            if (rowItem.modelData.kind === "cycle")
                                UserSettings[rowItem.modelData.setting] = rowItem.modelData.values[idx];
                        }
                    }

                    SkewToggle {
                        visible: rowItem.modelData.kind === "toggle"
                        state: rowItem.modelData.kind === "toggle"
                            && UserSettings[rowItem.modelData.setting]
                            ? 1 : 0
                    }
                }
            }
        }
    }
}
