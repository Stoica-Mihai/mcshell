import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Config

// Weather indicator — icon + temperature, click to toggle popup.
// Fetches from Open-Meteo (free, no API key) using curl via SafeProcess.
// Spins its icon while fetching. Auto-refreshes every 30 minutes.
Item {
    id: root

    // ── Public API ────────────────────────────────────────
    property bool popupVisible: false
    signal togglePopup()
    signal dismissPopup()

    // ── State exposed to WeatherPopup ─────────────────────
    property string fetchState: "idle"  // "idle" | "loading" | "ok" | "error"
    property string errorMsg: ""

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
    function fetch() {
        if (!UserSettings.weatherConfigured) return;
        root.fetchState = "loading";
        const url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + UserSettings.weatherLat
            + "&longitude=" + UserSettings.weatherLon
            + "&current_weather=true"
            + "&current=relativehumidity_2m,apparent_temperature"
            + "&hourly=temperature_2m,weathercode"
            + "&daily=temperature_2m_max,temperature_2m_min,weathercode"
            + "&forecast_days=5"
            + "&timezone=auto";
        fetchProc.command = ["curl", "-s", "--max-time", "10", url];
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    if (!data.current_weather) throw new Error("No current_weather in response");
                    root._onFetchSuccess(data);
                } catch (e) {
                    root._onFetchError("Could not parse weather data");
                }
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.fetchState === "loading")
                root._onFetchError("Network error");
        }
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

        fetchState = "ok";
        errorMsg = "";
    }

    function _onFetchError(msg) {
        fetchState = "error";
        errorMsg = msg;
    }

    // ── Weather code → icon + color ───────────────────────
    function iconForCode(code) {
        if (code === 0) return Theme.iconSun;
        if (code >= 1 && code <= 3) return Theme.iconCloudSun;
        if (code === 45 || code === 48) return Theme.iconSmog;
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return Theme.iconCloudRain;
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return Theme.iconSnowflake;
        if (code >= 95) return Theme.iconBolt;
        return Theme.iconCloud;
    }

    function colorForCode(code) {
        if (code === 0 || (code >= 1 && code <= 3)) return Theme.yellow;
        if (code === 45 || code === 48) return Theme.fgDim;
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return Theme.cyan;
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return Theme.fg;
        if (code >= 95) return Theme.red;
        return Theme.fgDim;
    }

    // ── Auto-refresh ──────────────────────────────────────
    Timer {
        interval: 30 * 60 * 1000  // 30 minutes
        running: UserSettings.weatherConfigured
        repeat: true
        onTriggered: root.fetch()
    }

    Component.onCompleted: {
        if (UserSettings.weatherConfigured) fetch();
    }

    // Refetch when location changes
    Connections {
        target: UserSettings
        function onWeatherLatChanged() { if (UserSettings.weatherConfigured) root.fetch(); }
        function onWeatherLonChanged() { if (UserSettings.weatherConfigured) root.fetch(); }
    }

    // ── Display ───────────────────────────────────────────
    readonly property string _displayIcon: {
        if (!UserSettings.weatherConfigured) return Theme.iconWeatherQuestion;
        if (fetchState === "error") return Theme.iconWeatherError;
        return iconForCode(weatherCode);
    }
    readonly property color _displayColor: {
        if (!UserSettings.weatherConfigured) return Theme.fgDim;
        if (fetchState === "error") return Theme.red;
        return colorForCode(weatherCode);
    }
    readonly property string _displayLabel: {
        if (!UserSettings.weatherConfigured || fetchState === "error") return "--°";
        if (fetchState === "loading" && tempC === 0) return "--°";
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

                // Spin animation while fetching
                RotationAnimation on rotation {
                    from: 0; to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: root.fetchState === "loading"
                    onRunningChanged: if (!running) iconText.rotation = 0
                }
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
        onClicked: {
            root.fetch();  // Always refresh on open
            root.togglePopup();
        }
    }
}
