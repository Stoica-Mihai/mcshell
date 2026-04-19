import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Core
import qs.Widgets

// Weather dropdown content.
// - Unconfigured: shows search field for city, user picks from results to set location
// - Loaded: shows current + hourly + 5-day forecast
// - Loaded + edit mode: same as unconfigured but can cancel back to current weather
// - Error: red warning + retry hint
Item {
    id: root

    property var weather: null  // Bar/Weather.qml instance

    // Default: edit mode if no location is configured (onboarding), view mode otherwise.
    property bool editMode: !UserSettings.weatherConfigured

    property var geoResults: []
    property string geoError: ""
    readonly property bool geoLoading: _geocodeFetcher.loading
    property int selectedIndex: 0

    readonly property real fullHeight: content.implicitHeight + Theme.spacingNormal * 2

    anchors.fill: parent

    onVisibleChanged: {
        if (visible) {
            // Only reset to default if not already explicitly set to edit (e.g. via WeatherWindow.toggleEdit)
            if (!editMode) editMode = !UserSettings.weatherConfigured;
            _resetGeocode();
            if (editMode) _focusTimer.restart();
        } else {
            // Reset to default state on hide so next open picks the right mode
            editMode = !UserSettings.weatherConfigured;
        }
    }

    // Delay focus grab until after the popup open animation + any FocusScope setup.
    Timer {
        id: _focusTimer
        interval: Theme.animSmooth + 50
        onTriggered: if (root.editMode && searchField.visible) searchField.forceActiveFocus()
    }

    function _resetGeocode() {
        _geocodeFetcher.cancel();
        geoResults = [];
        geoError = "";
        searchField.text = "";
    }

    // ── Geocoding ────────────────────────────────────────
    function _doGeocode(query) {
        if (query.trim().length < 2) {
            geoResults = [];
            geoError = "";
            return;
        }
        geoError = "";
        _geocodeFetcher.fetch(
            `https://geocoding-api.open-meteo.com/v1/search`
            + `?name=${encodeURIComponent(query.trim())}`
            + `&count=8&language=en&format=json`);
    }

    Timer {
        id: debounceTimer
        interval: 300
        onTriggered: root._doGeocode(searchField.text)
    }

    JsonFetcher {
        id: _geocodeFetcher
        timeoutSeconds: 8
        onSuccess: data => {
            const results = data.results ?? [];
            const items = [];
            for (let i = 0; i < results.length; i++) {
                const r = results[i];
                const parts = [r.name];
                if (r.admin1 && r.admin1 !== r.name) parts.push(r.admin1);
                if (r.country) parts.push(r.country);
                items.push({
                    name: r.name,
                    admin1: r.admin1 ?? "",
                    country: r.country ?? "",
                    countryCode: r.country_code ?? "",
                    latitude: r.latitude,
                    longitude: r.longitude,
                    displayName: parts.join(", ")
                });
            }
            root.geoResults = items;
            root.selectedIndex = 0;
            root.geoError = items.length === 0 ? "No cities found" : "";
        }
        onError: reason => {
            root.geoResults = [];
            root.geoError = reason === "offline" ? "No network connection"
                : reason === "parse" ? "Could not reach geocoding service"
                : "Network error";
        }
    }

    function selectLocation(loc) {
        UserSettings.weatherLocation = loc.displayName;
        UserSettings.weatherLat = loc.latitude;
        UserSettings.weatherLon = loc.longitude;
        if (loc.countryCode) UserSettings.weatherCountryCode = loc.countryCode;
        editMode = false;
        _resetGeocode();
    }

    // ── Progress line at top during weather fetch ───────
    Rectangle {
        id: progressLine
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: "transparent"
        opacity: weather && weather.fetchState === "loading" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        z: 10

        Rectangle {
            id: progressInner
            height: parent.height
            width: parent.width * 0.35
            color: Theme.accent
            opacity: 0.8

            SequentialAnimation on x {
                running: progressLine.opacity > 0
                loops: Animation.Infinite
                NumberAnimation { from: -progressInner.width; to: progressLine.width; duration: 1200; easing.type: Easing.InOutQuad }
            }
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingNormal
        spacing: Theme.spacingSmall

        // ── EDIT MODE: search field + results ────────────
        ColumnLayout {
            visible: root.editMode
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            // Header — "Set location" with cancel if configured
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28

                Text {
                    anchors.centerIn: parent
                    text: UserSettings.weatherConfigured ? "Change location" : "Set your location"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Medium
                    color: Theme.fg
                }

                IconButton {
                    visible: UserSettings.weatherConfigured
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Theme.iconClose
                    size: 12
                    implicitWidth: 24
                    implicitHeight: 24
                    normalColor: Theme.fgDim
                    onClicked: {
                        root.editMode = false;
                        root._resetGeocode();
                    }
                }
            }

            // Search input
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Theme.radiusMedium
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: searchField.activeFocus ? Theme.accent : Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMedium
                    anchors.rightMargin: Theme.spacingMedium
                    spacing: Theme.spacingNormal

                    Text {
                        text: Theme.iconSearch
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: Theme.fgDim
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        clip: true
                        selectByMouse: true

                        onTextChanged: debounceTimer.restart()

                        Keys.onReturnPressed: {
                            if (root.geoResults.length > 0
                                && root.selectedIndex >= 0
                                && root.selectedIndex < root.geoResults.length)
                                root.selectLocation(root.geoResults[root.selectedIndex]);
                        }
                        Keys.onDownPressed: {
                            if (root.geoResults.length === 0) return;
                            root.selectedIndex = (root.selectedIndex + 1) % root.geoResults.length;
                        }
                        Keys.onUpPressed: {
                            if (root.geoResults.length === 0) return;
                            root.selectedIndex = (root.selectedIndex - 1 + root.geoResults.length) % root.geoResults.length;
                        }
                        Keys.onEscapePressed: {
                            if (UserSettings.weatherConfigured) {
                                root.editMode = false;
                                root._resetGeocode();
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search city..."
                            color: Theme.fgDim
                            font: parent.font
                            visible: !parent.text && !parent.activeFocus
                        }
                    }
                }
            }

            // Empty hint / error / results
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(60, Math.min(root.geoResults.length * 40, 240))

                // Hint when no query yet
                Text {
                    anchors.centerIn: parent
                    visible: !root.geoLoading && root.geoResults.length === 0 && root.geoError === "" && searchField.text.trim().length < 2
                    text: "Start typing to search cities"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fgDim
                }

                // Loading
                Text {
                    anchors.centerIn: parent
                    visible: root.geoLoading
                    text: "Searching..."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fgDim
                }

                // Error
                Text {
                    anchors.centerIn: parent
                    visible: !root.geoLoading && root.geoError !== ""
                    text: root.geoError
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.red
                }

                // Results list
                ListView {
                    id: resultsList
                    anchors.fill: parent
                    visible: !root.geoLoading && root.geoResults.length > 0
                    clip: true
                    model: root.geoResults
                    spacing: 2
                    interactive: contentHeight > height
                    currentIndex: root.selectedIndex
                    highlightFollowsCurrentItem: true
                    // Keep selected item visible as user arrows through
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: resultRow
                        required property var modelData
                        required property int index

                        readonly property bool _isSelected: root.selectedIndex === index

                        width: ListView.view.width
                        height: 36
                        radius: Theme.radiusSmall
                        color: _isSelected ? Theme.accentLight
                             : mouse.containsMouse ? Theme.bgHover
                             : "transparent"
                        border.width: _isSelected ? 1 : 0
                        border.color: Theme.accent

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingMedium
                            anchors.rightMargin: Theme.spacingMedium
                            spacing: Theme.spacingMedium

                            Text {
                                text: Theme.iconLocationPin
                                font.family: Theme.iconFont
                                font.pixelSize: 13
                                color: resultRow._isSelected ? Theme.accent : Theme.fgDim
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.displayName
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.fg
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectLocation(modelData)
                        }
                    }
                }
            }
        }

        // ── ERROR STATE: weather fetch failed ────────────
        ColumnLayout {
            visible: !root.editMode && UserSettings.weatherConfigured && weather && weather.fetchState === "error"
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            spacing: Theme.spacingNormal

            Item { Layout.preferredHeight: Theme.spacingSmall }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Theme.iconWeatherError
                font.family: Theme.iconFont
                font.pixelSize: 32
                color: Theme.red
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Could not load weather"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fg
                font.weight: Font.Medium
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                text: (weather?.errorMsg ?? "") + "\nCheck your location or network"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.fgDim
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Click here to change location"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.accent

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.editMode = true;
                        Qt.callLater(() => searchField.forceActiveFocus());
                    }
                }
            }

            Item { Layout.preferredHeight: Theme.spacingSmall }
        }

        // ── LOADED STATE: current + hourly + daily ────────
        ColumnLayout {
            visible: !root.editMode && UserSettings.weatherConfigured && weather && weather.fetchState !== "error"
            Layout.fillWidth: true
            spacing: Theme.spacingSmall
            opacity: (weather && weather.fetchState === "loading") ? 0.55 : 1.0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

            // Header — location + edit pencil
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

            // Current row — big icon, cond, temp
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingSmall
                Layout.rightMargin: Theme.spacingSmall
                spacing: Theme.spacingLarge

                Text {
                    text: weather ? WeatherCodes.icon(weather.weatherCode) : Theme.iconCloud
                    font.family: Theme.iconFont
                    font.pixelSize: 40
                    color: weather ? WeatherCodes.color(weather.weatherCode) : Theme.fgDim
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        text: weather ? WeatherCodes.name(weather.weatherCode) : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }

                    Text {
                        text: weather
                            ? `Feels ${Math.round(weather.feelsLike)}° · Humidity ${weather.humidity}%`
                            : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fgDim
                    }
                }

                Text {
                    text: weather ? Math.round(weather.tempC) + "°" : "--°"
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
                    model: weather ? weather.hourly : []

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
                                text: index === 0
                                    ? "Now"
                                    : Qt.formatDateTime(modelData.time, "hh")
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
                    model: weather ? weather.daily : []

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
                visible: weather && weather.lastRefresh.getTime() > 0
                text: weather
                    ? `Updated ${weather.lastRefresh.toLocaleTimeString(
                        Qt.locale(),
                        UserSettings.clockTimeFormat === "12h" ? "h:mm AP" : "HH:mm")}`
                    : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMini
                color: Theme.fgDim
            }
        }
    }

}
