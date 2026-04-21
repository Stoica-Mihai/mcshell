import QtQuick
import Quickshell.Io
import Quickshell.Networking

// One-shot JSON fetcher: curl `url`, parse response, emit success(data) or
// error(reason ∈ {"offline","network","parse"}). Emits "offline" without
// running curl when Networking.connectivity !== Full. Single-flight — fetch()
// is dropped while a previous request is in flight; cancel() aborts it.
Item {
    id: root

    property int timeoutSeconds: 10
    // After a network failure (curl timeout / non-zero exit), silently drop
    // further fetches for this many seconds so flapping connectivity can't
    // spawn a train of overlapping curl processes.
    property int cooldownSeconds: 5
    readonly property bool loading: _proc.running

    property real _nextAllowedAt: 0

    signal success(var data)
    signal error(string reason)

    function fetch(url) {
        if (_proc.running || !url) return;
        if (Date.now() < _nextAllowedAt) return;
        if (Networking.connectivity !== NetworkConnectivity.Full) {
            root.error("offline");
            return;
        }
        _proc._handled = false;
        _proc.command = ["curl", "-s", "--max-time", timeoutSeconds.toString(), url];
        _proc.running = true;
    }

    // Abort an in-flight fetch. Suppresses both the success and error signals
    // for the cancelled request so callers can safely reset their state.
    function cancel() {
        if (!_proc.running) return;
        _proc._handled = true;
        _proc.running = false;
    }

    Process {
        id: _proc
        property bool _handled: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (_proc._handled) return;
                _proc._handled = true;
                try {
                    root.success(JSON.parse(this.text));
                } catch (e) {
                    root.error("parse");
                }
            }
        }
        onExited: code => {
            if (_proc._handled) return;
            _proc._handled = true;
            if (code !== 0) root._nextAllowedAt = Date.now() + root.cooldownSeconds * 1000;
            root.error(code !== 0 ? "network" : "parse");
        }
    }
}
