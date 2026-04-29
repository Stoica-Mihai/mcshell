import QtQuick
import Quickshell.Io
import Quickshell.Networking

// One-shot JSON fetcher: HTTP GET `url`, parse response, emit success(data)
// or error(reason ∈ {"offline","network","parse"}). Emits "offline" without
// issuing the request when Networking.connectivity !== Full. Single-flight —
// fetch() is dropped while a previous request is in flight; cancel() aborts it.
Item {
    id: root

    property int timeoutSeconds: 10
    // After a network failure (timeout / non-2xx), silently drop further
    // fetches for this many seconds so flapping connectivity can't spawn a
    // train of overlapping requests.
    property int cooldownSeconds: 5
    readonly property bool loading: _http.loading

    property real _nextAllowedAt: 0

    signal success(var data)
    signal error(string reason)

    function fetch(url) {
        if (_http.loading || !url) return;
        if (Date.now() < _nextAllowedAt) return;
        if (Networking.connectivity !== NetworkConnectivity.Full) {
            root.error("offline");
            return;
        }
        _http.timeoutSeconds = root.timeoutSeconds;
        _http.fetch(url);
    }

    function cancel() { _http.cancel(); }

    HttpFetcher {
        id: _http
        onResponse: (status, body, errStr) => {
            if (errStr) {
                if (errStr === "timeout" || errStr === "network" || errStr === "http") {
                    root._nextAllowedAt = Date.now() + root.cooldownSeconds * 1000;
                }
                root.error(errStr === "timeout" || errStr === "network" ? "network"
                         : errStr === "http" ? "network" : "parse");
                return;
            }
            try {
                root.success(JSON.parse(body.toString()));
            } catch (e) {
                root.error("parse");
            }
        }
    }
}
