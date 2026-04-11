import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.Config
import qs.Core

// Weather indicator — icon + temperature, click to toggle popup.
// Fetches from Open-Meteo (free, no API key) via Core/JsonFetcher.
// Auto-refreshes every 30 minutes and when the network becomes available.
Item {
    id: root

    // ── Public API ────────────────────────────────────────
    property bool popupVisible: false
    signal togglePopup()
    signal toggleEditPopup()
    signal dismissPopup()

    // ── State exposed to WeatherPopup ─────────────────────
    property string fetchState: "idle"  // "idle" | "loading" | "ok" | "error"
    property string errorMsg: ""
    // Epoch-0 sentinel means "never refreshed" — the popup hides the footer.
    property date lastRefresh: new Date(0)

    // Current conditions
    property real tempC: 0
    property int weatherCode: 0
    property real feelsLike: 0
    property int humidity: 0

    // Hourly forecast — array of { time: Date, temp: real, code: int }
    property var hourly: []
    // Daily forecast — array of { date: Date, max: real, min: real, code: int }
    property var daily: []

    // ── Size ──────────────────────────────────────────────
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    visible: true

    // ── Fetch trigger ─────────────────────────────────────
    // Gate on connectivity here so we don't flip fetchState → loading while
    // offline — the Connections block below picks up the retry once the
    // network comes back.
    function fetch() {
        if (!UserSettings.weatherConfigured) return;
        if (Networking.connectivity !== NetworkConnectivity.Full) return;
        root.fetchState = "loading";
        _fetcher.fetch(
            `https://api.open-meteo.com/v1/forecast`
            + `?latitude=${UserSettings.weatherLat}&longitude=${UserSettings.weatherLon}`
            + `&current_weather=true`
            + `&current=relativehumidity_2m,apparent_temperature`
            + `&hourly=temperature_2m,weathercode`
            + `&daily=temperature_2m_max,temperature_2m_min,weathercode`
            + `&forecast_days=5&timezone=auto`);
    }

    JsonFetcher {
        id: _fetcher
        onSuccess: data => {
            if (!data.current_weather) {
                root._onFetchError("Could not parse weather data");
                return;
            }
            root._onFetchSuccess(data);
        }
        onError: reason => {
            root._onFetchError(reason === "parse" ? "Could not parse weather data" : "Network error");
        }
    }

    // Retry when the network genuinely transitions from not-Full to Full.
    ConnectivityRetry {
        onTriggered: if (UserSettings.weatherConfigured) root.fetch()
    }

    function _onFetchSuccess(data) {
        tempC = data.current_weather.temperature;
        weatherCode = data.current_weather.weathercode;
        feelsLike = data.current?.apparent_temperature?.[0] ?? tempC;
        humidity = data.current?.relativehumidity_2m?.[0] ?? 0;

        // Hourly — pick next 8 hours starting from current hour
        const nowHour = new Date().getHours();
        const hourlyArr = [];
        const times = data.hourly?.time ?? [];
        const temps = data.hourly?.temperature_2m ?? [];
        const codes = data.hourly?.weathercode ?? [];
        let startIdx = 0;
        for (let i = 0; i < times.length; i++) {
            if (new Date(times[i]).getHours() === nowHour
                && new Date(times[i]).getDate() === new Date().getDate()) {
                startIdx = i;
                break;
            }
        }
        for (let i = 0; i < 8 && (startIdx + i) < times.length; i++) {
            const j = startIdx + i;
            hourlyArr.push({
                time: new Date(times[j]),
                temp: temps[j],
                code: codes[j]
            });
        }
        hourly = hourlyArr;

        // Daily — all 5 days
        const dailyArr = [];
        const dTimes = data.daily?.time ?? [];
        const dMax = data.daily?.temperature_2m_max ?? [];
        const dMin = data.daily?.temperature_2m_min ?? [];
        const dCodes = data.daily?.weathercode ?? [];
        for (let i = 0; i < dTimes.length; i++) {
            dailyArr.push({
                date: new Date(dTimes[i]),
                max: dMax[i],
                min: dMin[i],
                code: dCodes[i]
            });
        }
        daily = dailyArr;

        lastRefresh = new Date();
        fetchState = "ok";
        errorMsg = "";
    }

    function _onFetchError(msg) {
        fetchState = "error";
        errorMsg = msg;
    }

    Timer {
        interval: 30 * 60 * 1000
        running: UserSettings.weatherConfigured
        repeat: true
        onTriggered: root.fetch()
    }

    Component.onCompleted: {
        if (UserSettings.weatherConfigured) fetch();
    }

    Connections {
        target: UserSettings
        function onWeatherLatChanged() { if (UserSettings.weatherConfigured) root.fetch(); }
        function onWeatherLonChanged() { if (UserSettings.weatherConfigured) root.fetch(); }
    }

    // ── Display ───────────────────────────────────────────
    // True while we have no usable reading yet (fresh startup, network still
    // coming up, or a retry pending after an error).
    readonly property bool _noData: fetchState !== "ok" && tempC === 0
    readonly property string _displayIcon: {
        if (!UserSettings.weatherConfigured || _noData) return Theme.iconWeatherQuestion;
        if (fetchState === "error") return Theme.iconWeatherError;
        return WeatherCodes.icon(weatherCode);
    }
    readonly property color _displayColor: {
        if (!UserSettings.weatherConfigured || _noData) return Theme.fgDim;
        if (fetchState === "error") return Theme.red;
        return WeatherCodes.color(weatherCode);
    }
    readonly property string _displayLabel: {
        if (!UserSettings.weatherConfigured || fetchState === "error" || _noData) return "--°";
        return Math.round(tempC) + "°";
    }

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

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            root.fetch();  // always refresh on open
            if (event.button === Qt.RightButton) root.toggleEditPopup();
            else root.togglePopup();
        }
    }
}
