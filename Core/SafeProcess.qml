import QtQuick
import Quickshell.Io

// Process wrapper with built-in error logging.
// Drop-in replacement for Process — adds failMessage and onFailed signal.
Item {
    id: root

    property var command: []
    property string failMessage: command[0] ?? "Process"
    property bool running: false

    signal read(string data)
    signal finished()
    signal failed(int exitCode)

    onRunningChanged: {
        if (running)
            proc.running = true;
    }

    Process {
        id: proc
        command: root.command
        running: root.running

        stdout: SplitParser {
            onRead: data => root.read(data)
        }

        onExited: (exitCode, exitStatus) => {
            root.running = false;
            if (exitCode !== 0) {
                console.warn("[mcshell]", root.failMessage + ":", "exit code", exitCode);
                root.failed(exitCode);
            } else {
                root.finished();
            }
        }
    }
}
