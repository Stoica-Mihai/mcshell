import QtQuick
import Quickshell.Io

// Reusable Process + Timer polling pattern.
// Set `command` and `interval`, handle `onRead(data)`.
Item {
    id: root

    property var command: []
    property int interval: 1000
    property bool active: true

    signal read(string data)

    function run() {
        proc.running = true;
    }

    Process {
        id: proc
        command: root.command
        stdout: SplitParser {
            onRead: data => root.read(data)
        }
    }

    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
