pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Config

// Single owner of the Open-Meteo forecast fetch + state. One instance for the
// whole shell, so N status bars (N monitors) share one fetch/timer set instead
// of each running its own. Bar/Weather.qml and Bar/WeatherPopup.qml are views
// that bind to these properties.
Singleton {
    id: root

    // ── State (read by the bar widget + popup) ────────────
    property string fetchState: "idle"  // "idle" | "loading" | "ok" | "error"
    property string errorMsg: ""
    // Epoch-0 sentinel means "never refreshed" — the popup hides the footer.
    property date lastRefresh: new Date(0)

    property real tempC: 0
    property int weatherCode: 0
    property real feelsLike: 0
    property int humidity: 0

    // Hourly: [{ time: Date, temp: real, code: int }]; Daily: [{ date, max, min, code }]
    property var hourly: []
    property var daily: []

    // Once a reading lands we keep showing it through transient errors.
    property bool hasData: false

    // ── Fetch ─────────────────────────────────────────────
    // Gate on connectivity so we don't flip to loading while offline — the
    // ConnectivityRetry below picks it up once the network comes back.
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

        // Hourly — pick next 8 hours starting from the current hour
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
            hourlyArr.push({ time: new Date(times[j]), temp: temps[j], code: codes[j] });
        }
        hourly = hourlyArr;

        // Daily — all 5 days
        const dailyArr = [];
        const dTimes = data.daily?.time ?? [];
        const dMax = data.daily?.temperature_2m_max ?? [];
        const dMin = data.daily?.temperature_2m_min ?? [];
        const dCodes = data.daily?.weathercode ?? [];
        for (let i = 0; i < dTimes.length; i++) {
            dailyArr.push({ date: new Date(dTimes[i]), max: dMax[i], min: dMin[i], code: dCodes[i] });
        }
        daily = dailyArr;

        lastRefresh = new Date();
        fetchState = "ok";
        errorMsg = "";
        hasData = true;
        errorRetry.stop();
    }

    function _onFetchError(msg) {
        fetchState = "error";
        errorMsg = msg;
        // Recover fast from a transient blip instead of waiting for the 30-min
        // refresh; JsonFetcher's own cooldown prevents spamming.
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

    // Keep retrying until the first reading lands — covers a startup where
    // connectivity wasn't Full yet and no not-Full→Full transition fired.
    Timer {
        interval: 10 * 1000
        repeat: true
        running: UserSettings.weatherConfigured && !root.hasData
        onTriggered: root.fetch()
    }

    // Debounce coord edits so dragging a slider or editing both fields back to
    // back doesn't spawn overlapping requests.
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

    Component.onCompleted: if (UserSettings.weatherConfigured) fetch();
}
