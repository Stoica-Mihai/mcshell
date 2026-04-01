import QtQuick
import Quickshell.Io

// PolledProcess wrapper with built-in error logging.
// Drop-in replacement for PolledProcess — adds failMessage and onFailed signal.
Item {
    id: root

    property var command: []
    property int interval: 1000
    property bool active: true
    property string failMessage: command[0] ?? "Process"

    signal read(string data)
    signal finished()
    signal failed(int exitCode)

    function run() {
        proc.running = true;
    }

    Process {
        id: proc
        command: root.command

        stdout: SplitParser {
            onRead: data => root.read(data)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("[mcshell]", root.failMessage + ":", "exit code", exitCode);
                root.failed(exitCode);
            } else {
                root.finished();
            }
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
