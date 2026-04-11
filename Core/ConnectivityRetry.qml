import QtQuick
import Quickshell.Networking

// Emits `triggered()` on every not-Full → Full connectivity transition.
// _lastConnectivity is a plain property so the handler compares against the
// value it last observed, not the live one.
Item {
    id: root

    signal triggered()

    property int _lastConnectivity: NetworkConnectivity.None

    Connections {
        target: Networking
        function onConnectivityChanged() {
            const curr = Networking.connectivity;
            if (curr === NetworkConnectivity.Full
                && root._lastConnectivity !== NetworkConnectivity.Full)
                root.triggered();
            root._lastConnectivity = curr;
        }
    }
}
