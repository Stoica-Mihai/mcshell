import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Core
import qs.Widgets

// Weather dropdown content. Delegates rendering to one of three state views:
//   - WeatherEditView:   search UI for initial onboarding / location change
//   - WeatherErrorView:  fetch failed — show a retry affordance
//   - WeatherLoadedView: current + hourly + 5-day forecast
Item {
    id: root

    property var weather: null  // Bar/Weather.qml instance

    // Default: edit mode if no location is configured (onboarding), view mode otherwise.
    property bool editMode: !UserSettings.weatherConfigured

    property var geoResults: []
    property string geoError: ""
    readonly property bool geoLoading: _geocodeFetcher.loading
    property int selectedIndex: 0

    readonly property real fullHeight: (viewLoader.item ? viewLoader.item.implicitHeight : 0) + Theme.spacingNormal * 2

    anchors.fill: parent

    onVisibleChanged: {
        if (visible) {
            // Only reset to default if not already explicitly set to edit (e.g. via WeatherWindow.toggleEdit)
            if (!editMode) editMode = !UserSettings.weatherConfigured;
            _resetGeocode();
        } else {
            // Reset to default state on hide so next open picks the right mode
            editMode = !UserSettings.weatherConfigured;
        }
    }

    function _resetGeocode() {
        _geocodeFetcher.cancel();
        geoResults = [];
        geoError = "";
    }

    function cancelEdit() {
        editMode = false;
        _resetGeocode();
    }

    function requestEdit() {
        editMode = true;
    }

    function queueGeocode(text) {
        _pendingQuery = text;
        debounceTimer.restart();
    }

    property string _pendingQuery: ""

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
        onTriggered: root._doGeocode(root._pendingQuery)
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

    // ── State dispatch ─────────────────────────────────
    readonly property string _state: editMode ? "edit"
        : (weather && weather.fetchState === "error" && UserSettings.weatherConfigured) ? "error"
        : "loaded"

    Loader {
        id: viewLoader
        anchors.fill: parent
        anchors.margins: Theme.spacingNormal
        sourceComponent: {
            switch (root._state) {
            case "edit":   return _editView;
            case "error":  return _errorView;
            default:       return _loadedView;
            }
        }
    }

    Component {
        id: _editView
        WeatherEditView { popup: root }
    }
    Component {
        id: _errorView
        WeatherErrorView {
            weather: root.weather
            onRequestEdit: root.requestEdit()
        }
    }
    Component {
        id: _loadedView
        WeatherLoadedView { weather: root.weather }
    }
}
