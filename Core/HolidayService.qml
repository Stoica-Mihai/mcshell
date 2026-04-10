pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

// Public holidays for the weather location's country.
// Source: Nager.Date (https://date.nager.at) — free, no auth, no rate limits.
// Cache is memory-only, keyed by "year-countryCode".
Singleton {
    id: root

    property var _cache: ({})
    property var _pending: ({})

    function holidayFor(date) {
        if (!date) return "";
        const map = _cachedMap(date.getFullYear());
        return map ? (map[Qt.formatDate(date, "yyyy-MM-dd")] || "") : "";
    }

    function holidaysInMonth(year, month) {
        const map = _cachedMap(year);
        if (!map) return [];
        const out = [];
        for (const k in map) {
            const d = new Date(k + "T00:00:00");
            if (d.getFullYear() === year && d.getMonth() === month)
                out.push({ date: d, name: map[k] });
        }
        out.sort((a, b) => a.date - b.date);
        return out;
    }

    // Side effect: kicks off a background fetch on cache miss so the next
    // binding re-evaluation picks up the data once it arrives.
    function _cachedMap(year) {
        const cc = UserSettings.weatherCountryCode;
        if (!cc || !year) return null;
        const key = year + "-" + cc;
        const map = _cache[key];
        if (!map) { ensureYear(year); return null; }
        return map;
    }

    function ensureYear(year) {
        const cc = UserSettings.weatherCountryCode;
        if (!cc || !year) return;
        const key = year + "-" + cc;
        if (_cache[key] || _pending[key]) return;
        _pending[key] = true;
        const url = "https://date.nager.at/api/v3/PublicHolidays/" + year + "/" + cc;
        _fetchProc.command = ["curl", "-s", "--max-time", "10", url];
        _fetchProc._pendingKey = key;
        _fetchProc.running = true;
    }

    Process {
        id: _fetchProc
        property string _pendingKey: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const key = _fetchProc._pendingKey;
                // Skip if the pending key was cleared (e.g. country change mid-flight)
                if (!root._pending[key]) return;
                try {
                    const arr = JSON.parse(this.text);
                    const map = {};
                    for (let i = 0; i < arr.length; i++) {
                        const entry = arr[i];
                        if (entry && entry.date) {
                            map[entry.date] = entry.localName || entry.name || "";
                        }
                    }
                    const copy = Object.assign({}, root._cache);
                    copy[key] = map;
                    root._cache = copy;
                } catch (e) {
                    console.warn("HolidayService: parse failed for", key);
                }
                delete root._pending[key];
            }
        }
        onExited: code => {
            if (code !== 0) {
                console.warn("HolidayService: fetch failed for", _fetchProc._pendingKey, "(exit " + code + ")");
                delete root._pending[_fetchProc._pendingKey];
            }
        }
    }

    Connections {
        target: UserSettings
        function onWeatherCountryCodeChanged() {
            root._cache = ({});
            root._pending = ({});
        }
    }
}
