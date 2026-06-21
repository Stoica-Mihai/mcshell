import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Widgets

SettingsPanelBase {
    id: root

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
    rows: [
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

    // Preview ticker — gated on window visibility so it doesn't run perpetually.
    SystemClock {
        id: previewClock
        precision: SystemClock.Seconds
        enabled: root.windowOpen
    }

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

    SettingsRowRepeater {
        model: root.rows
        selectedRow: root.selectedRow
        sectionTick: false
    }
}
