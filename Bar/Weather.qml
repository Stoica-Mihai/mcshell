import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Core
import qs.Widgets

// Weather indicator — icon + temperature, click to toggle popup. View only:
// all fetching/state lives in the Core/WeatherService singleton so the fetch
// runs once for the whole shell, not once per status bar (per monitor).
Item {
    id: root

    // ── Public API ────────────────────────────────────────
    property bool popupVisible: false
    signal togglePopup()
    signal toggleEditPopup()
    signal dismissPopup()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    visible: true

    // ── Display ───────────────────────────────────────────
    // Once a reading lands, keep showing it through transient errors — a blip
    // shouldn't blank the widget. Error/question only shows before first data;
    // staleness is surfaced in the popup footer via lastRefresh.
    readonly property string _displayIcon: {
        if (!UserSettings.weatherConfigured) return Theme.iconWeatherQuestion;
        if (WeatherService.hasData) return WeatherCodes.icon(WeatherService.weatherCode);
        if (WeatherService.fetchState === "error") return Theme.iconWeatherError;
        return Theme.iconWeatherQuestion;
    }
    readonly property color _displayColor: {
        if (!UserSettings.weatherConfigured) return Theme.fgDim;
        if (WeatherService.hasData) return WeatherCodes.color(WeatherService.weatherCode);
        if (WeatherService.fetchState === "error") return Theme.red;
        return Theme.fgDim;
    }
    readonly property string _displayLabel: WeatherService.hasData
        ? Math.round(WeatherService.tempC) + "°"
        : "--°"

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: iconText.implicitWidth
            implicitHeight: iconText.implicitHeight

            Text {
                id: iconText
                anchors.centerIn: parent
                text: root._displayIcon
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
                color: root._displayColor
                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root._displayLabel
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            color: Theme.fg
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }
    }

    BarClickArea {
        anchors.fill: parent
        onLeftClicked:  { WeatherService.fetch(); root.togglePopup(); }
        onRightClicked: { WeatherService.fetch(); root.toggleEditPopup(); }
    }
}
