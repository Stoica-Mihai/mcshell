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

    property int selectedRow: 0

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
            section: "Time",
            label: "Time format",
            setting: "clockTimeFormat",
            values: ["24h", "12h"],
            model:  ["24 hour", "12 hour"]
        },
        {
            section: "",
            label: "Show seconds",
            setting: "clockShowSeconds",
            values: [false, true],
            model:  ["Off", "On"]
        },
        {
            section: "",
            label: "Date format",
            setting: "clockDateFormat",
            values: _dateFormatPatterns,
            model:  _dateFormatLabels
        },
        {
            section: "Calendar",
            label: "Week starts on",
            setting: "weekStartsOnMonday",
            values: [true, false],
            model:  ["Monday", "Sunday"]
        }
    ]
    readonly property int rowCount: _rows.length

    // Preview ticker — gated on window visibility so it doesn't run perpetually.
    SystemClock {
        id: previewClock
        precision: SystemClock.Seconds
        enabled: root.windowOpen
    }

    anchors.fill: parent
    focus: true

    onWindowOpenChanged: if (windowOpen) { selectedRow = 0; forceActiveFocus(); }

    Keys.onUpPressed: selectedRow = (selectedRow - 1 + rowCount) % rowCount
    Keys.onDownPressed: selectedRow = (selectedRow + 1) % rowCount
    Keys.onLeftPressed: {
        const d = rowRepeater.itemAt(selectedRow);
        if (d) d.cycler.cycleLeft();
    }
    Keys.onRightPressed: {
        const d = rowRepeater.itemAt(selectedRow);
        if (d) d.cycler.cycleRight();
    }

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
                        model: rowItem.modelData.model
                        currentIndex: Math.max(0,
                            rowItem.modelData.values.indexOf(UserSettings[rowItem.modelData.setting]))
                        onIndexChanged: idx => {
                            UserSettings[rowItem.modelData.setting] = rowItem.modelData.values[idx];
                        }
                    }
                }
            }
        }
    }
}
