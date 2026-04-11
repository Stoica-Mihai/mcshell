pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Config

// Public holidays for the weather location's country.
// Source: Nager.Date (https://date.nager.at) — free, no auth, no rate limits.
// Cache is memory-only, keyed by "year-countryCode".
Singleton {
    id: root

    property var _cache: ({})
    property var _pending: ({})
    // Bumped on every false→Full connectivity transition. _cachedMap takes
    // this as a binding dependency so stale-empty years get a retry when
    // the network comes back up.
    property int _retryTick: 0

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
    // binding re-evaluation picks up the data once it arrives. _retryTick
    // is a binding dependency — a false→Full connectivity transition bumps
    // it, which re-evaluates every consumer binding and retries the fetch.
    function _cachedMap(year) {
        _retryTick;
        const cc = UserSettings.weatherCountryCode;
        if (!cc || !year) return null;
        const key = `${year}-${cc}`;
        const map = _cache[key];
        if (!map) { ensureYear(year); return null; }
        return map;
    }

    function ensureYear(year) {
        const cc = UserSettings.weatherCountryCode;
        if (!cc || !year) return;
        const key = `${year}-${cc}`;
        if (_cache[key] || _pending[key]) return;
        // Single-flight: drop if another year is in-flight. The consumer
        // binding will re-eval and call back in once the running fetch
        // completes (its _cache assignment triggers re-evaluation).
        if (_fetcher.loading) return;
        _pending[key] = true;
        _fetcher._pendingKey = key;
        _fetcher.fetch(`https://date.nager.at/api/v3/PublicHolidays/${year}/${cc}`);
    }

    JsonFetcher {
        id: _fetcher
        property string _pendingKey: ""
        onSuccess: data => {
            const key = _fetcher._pendingKey;
            if (!root._pending[key]) return;
            const map = {};
            for (let i = 0; i < data.length; i++) {
                const entry = data[i];
                if (entry && entry.date) {
                    map[entry.date] = entry.localName || entry.name || "";
                }
            }
            const copy = Object.assign({}, root._cache);
            copy[key] = map;
            root._cache = copy;
            delete root._pending[key];
        }
        onError: reason => {
            const key = _fetcher._pendingKey;
            delete root._pending[key];
            if (reason !== "offline")
                console.warn(`HolidayService: fetch failed for ${key} (${reason})`);
        }
    }

    Connections {
        target: UserSettings
        function onWeatherCountryCodeChanged() {
            root._cache = ({});
            root._pending = ({});
        }
    }

    Connections {
        target: Networking
        property int _prev: Networking.connectivity
        function onConnectivityChanged() {
            const curr = Networking.connectivity;
            if (curr === NetworkConnectivity.Full && _prev !== NetworkConnectivity.Full)
                root._retryTick++;
            _prev = curr;
        }
    }
}
