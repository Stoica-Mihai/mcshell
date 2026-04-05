import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland._DataControl
import qs.Config
import qs.Core

// Screen recording state — managed via wf-recorder process lifecycle.
// Start/stop via toggleRecording(). Bar shows a pulsing red dot when active.
Item {
    id: root
    visible: false

    readonly property bool active: recorder.running
    readonly property string filePath: _currentPath
    property string _currentPath: ""

    function toggleRecording() {
        if (active) stop(); else start();
    }

    function start() {
        const ts = new Date().toISOString().replace(/[:.]/g, "-").replace("T", "_").slice(0, 19);
        const dir = Quickshell.env("HOME") + "/Videos";
        _currentPath = dir + "/recording_" + ts + ".mp4";
        mkdirProc.running = true;
    }

    function stop() {
        recorder.signal(2); // SIGINT
    }

    // Ensure output directory exists, detect focused output, then start
    Process {
        id: mkdirProc
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/Videos"]
        onExited: outputDetect.running = true
    }

    Process {
        id: outputDetect
        command: ["sh", "-c", "niri msg focused-output 2>/dev/null | head -1 | grep -oP '\\(\\K[^)]+' || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = this.text.trim();
                var cmd = ["wf-recorder", "-f", root._currentPath];
                if (output) cmd.splice(1, 0, "-o", output);
                recorder.command = cmd;
                recorder.running = true;
            }
        }
    }

    Process {
        id: recorder
        onExited: (code, status) => {
            ClipboardHistory.addText(root._currentPath);
            NotificationDispatcher.send("Recording saved", root._currentPath, 5000);
            root._currentPath = "";
        }
    }
}
