import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Core

// Weather popup "loaded" view: current conditions + hourly + 5-day forecast.
ColumnLayout {
    id: root

    required property var weather

    Layout.fillWidth: true
    spacing: Theme.spacingSmall
    opacity: (weather && weather.fetchState === "loading") ? 0.55 : 1.0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    // Header — location
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 28

        Text {
            anchors.centerIn: parent
            text: UserSettings.weatherLocation
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            color: Theme.fg
            elide: Text.ElideRight
        }
    }

    // Current row — big icon, condition, temp
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacingSmall
        Layout.rightMargin: Theme.spacingSmall
        spacing: Theme.spacingLarge

        Text {
            text: root.weather ? WeatherCodes.icon(root.weather.weatherCode) : Theme.iconCloud
            font.family: Theme.iconFont
            font.pixelSize: 40
            color: root.weather ? WeatherCodes.color(root.weather.weatherCode) : Theme.fgDim
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: root.weather ? WeatherCodes.name(root.weather.weatherCode) : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fg
            }

            Text {
                text: root.weather
                    ? `Feels ${Math.round(root.weather.feelsLike)}° · Humidity ${root.weather.humidity}%`
                    : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.fgDim
            }
        }

        Text {
            text: root.weather ? Math.round(root.weather.tempC) + "°" : "--°"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXLarge + 8
            font.weight: Font.Medium
            color: Theme.fg
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Hourly grid (8 cells)
    Grid {
        Layout.fillWidth: true
        columns: 8
        columnSpacing: 2
        rowSpacing: 0

        Repeater {
            model: root.weather ? root.weather.hourly : []

            Rectangle {
                required property var modelData
                required property int index

                width: (parent.width - (7 * 2)) / 8
                height: 44
                radius: Theme.radiusTiny
                color: index === 0 ? Theme.accent : "transparent"

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: index === 0 ? "Now" : Qt.formatDateTime(modelData.time, "hh")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMini
                        color: index === 0 ? Theme.bgSolid : Theme.fgDim
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: WeatherCodes.icon(modelData.code)
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: index === 0 ? Theme.bgSolid : WeatherCodes.color(modelData.code)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Math.round(modelData.temp) + "°"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMini
                        color: index === 0 ? Theme.bgSolid : Theme.fg
                    }
                }
            }
        }
    }

    // 5-day forecast
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: root.weather ? root.weather.daily : []

            Rectangle {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: 26
                radius: Theme.radiusTiny
                color: index === 0 ? Theme.withAlpha(Theme.accent, 0.08) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingSmall
                    anchors.rightMargin: Theme.spacingSmall
                    spacing: Theme.spacingSmall

                    Text {
                        Layout.preferredWidth: 46
                        text: index === 0 ? "Today" : Qt.formatDateTime(modelData.date, "ddd")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: index === 0 ? Theme.accent : Theme.fgDim
                    }

                    Text {
                        Layout.preferredWidth: 20
                        horizontalAlignment: Text.AlignHCenter
                        text: WeatherCodes.icon(modelData.code)
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: WeatherCodes.color(modelData.code)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: WeatherCodes.name(modelData.code)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fg
                        elide: Text.ElideRight
                    }

                    Text {
                        text: Math.round(modelData.max) + "°"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fg
                    }

                    Text {
                        text: "/ " + Math.round(modelData.min) + "°"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fgDim
                    }
                }
            }
        }
    }

    // Last refresh footer
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Theme.spacingTiny
        visible: root.weather && root.weather.lastRefresh.getTime() > 0
        text: root.weather
            ? `Updated ${root.weather.lastRefresh.toLocaleTimeString(
                Qt.locale(),
                UserSettings.clockTimeFormat === "12h" ? "h:mm AP" : "HH:mm")}`
            : ""
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMini
        color: Theme.fgDim
    }
}
