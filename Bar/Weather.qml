import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.Config
import qs.Core
import qs.Widgets

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
            + `&current=temperature_2m,weather_code,apparent_temperature,relative_humidity_2m`
            + `&hourly=temperature_2m,weathercode`
            + `&daily=temperature_2m_max,temperature_2m_min,weathercode`
            + `&forecast_days=5&timezone=auto`);
    }

    JsonFetcher {
        id: _fetcher
        onSuccess: data => {
            if (!data.current) {
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
        tempC = data.current.temperature_2m;
        weatherCode = data.current.weather_code;
        feelsLike = data.current.apparent_temperature ?? tempC;
        humidity = data.current.relative_humidity_2m ?? 0;

        // Hourly — pick next 8 hours starting from current hour
        const now = new Date();
        const nowHour = now.getHours();
        const today = now.getDate();
        const hourlyArr = [];
        const times = data.hourly?.time ?? [];
        const temps = data.hourly?.temperature_2m ?? [];
        const codes = data.hourly?.weathercode ?? [];
        let startIdx = 0;
        for (let i = 0; i < times.length; i++) {
            const t = new Date(times[i]);
            if (t.getHours() === nowHour && t.getDate() === today) {
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
        _hasData = true;
        errorRetry.stop();
    }

    function _onFetchError(msg) {
        fetchState = "error";
        errorMsg = msg;
        // Recover fast from a transient blip instead of waiting for the
        // 30-minute refresh; JsonFetcher's own cooldown prevents spamming.
        if (UserSettings.weatherConfigured) errorRetry.restart();
    }

    Timer {
        id: errorRetry
        interval: 90 * 1000
        repeat: false
        onTriggered: if (UserSettings.weatherConfigured) root.fetch()
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

    // Keep retrying until the first reading lands. Covers a startup where
    // Networking.connectivity wasn't Full yet when Component.onCompleted ran
    // (the fetch was gated) and no later not-Full→Full transition fired for
    // ConnectivityRetry to catch. Stops automatically once _hasData is set.
    Timer {
        interval: 10 * 1000
        repeat: true
        running: UserSettings.weatherConfigured && !root._hasData
        onTriggered: root.fetch()
    }

    // Debounce coord edits so dragging a settings slider or editing both
    // fields back-to-back doesn't spawn overlapping curl processes.
    Timer {
        id: coordRefetch
        interval: 500
        repeat: false
        onTriggered: if (UserSettings.weatherConfigured) root.fetch()
    }

    Connections {
        target: UserSettings
        function onWeatherLatChanged() { coordRefetch.restart(); }
        function onWeatherLonChanged() { coordRefetch.restart(); }
    }

    // ── Display ───────────────────────────────────────────
    // Once we have a successful reading we keep showing it through later
    // transient fetch errors — a single network blip shouldn't blank the
    // widget. The error/question state only shows before the first reading;
    // staleness is surfaced in the popup footer via lastRefresh.
    property bool _hasData: false
    readonly property string _displayIcon: {
        if (!UserSettings.weatherConfigured) return Theme.iconWeatherQuestion;
        if (_hasData) return WeatherCodes.icon(weatherCode);
        if (fetchState === "error") return Theme.iconWeatherError;
        return Theme.iconWeatherQuestion;
    }
    readonly property color _displayColor: {
        if (!UserSettings.weatherConfigured) return Theme.fgDim;
        if (_hasData) return WeatherCodes.color(weatherCode);
        if (fetchState === "error") return Theme.red;
        return Theme.fgDim;
    }
    readonly property string _displayLabel: {
        if (_hasData) return Math.round(tempC) + "°";
        return "--°";
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

    BarClickArea {
        anchors.fill: parent
        onLeftClicked:  { root.fetch(); root.togglePopup(); }
        onRightClicked: { root.fetch(); root.toggleEditPopup(); }
    }
}
