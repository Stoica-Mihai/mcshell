import QtQuick
import Quickshell
import Quickshell.Io
import Qs.DataControl
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
        _currentPath = `${Quickshell.env("HOME")}/Videos/recording_${ts}.mp4`;
        mkdirProc.running = true;
    }

    function stop() {
        recorder.signal(2); // SIGINT
    }

    // Ensure output directory exists, then start wf-recorder scoped to the
    // focused niri output.
    SafeProcess {
        id: mkdirProc
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/Videos"]
        failMessage: "failed to create recordings directory"
        onFinished: {
            const output = FocusedOutput.name;
            var cmd = ["wf-recorder", "-f", root._currentPath];
            if (output) cmd.splice(1, 0, "-o", output);
            recorder.command = cmd;
            recorder.running = true;
        }
    }

    Process {
        id: recorder
        onExited: (code, status) => {
            // wf-recorder exits non-zero on setup failures (missing codec, portal denial, etc.)
            // SIGINT stop returns 0, so only a non-zero code here means the recording failed.
            if (code !== 0) {
                console.warn("[mcshell] wf-recorder failed: exit code", code);
                NotificationDispatcher.send("Recording failed", `wf-recorder exit code ${code}`, 5000);
                root._currentPath = "";
                return;
            }
            ClipboardHistory.addText(root._currentPath);
            NotificationDispatcher.send("Recording saved", root._currentPath, 5000);
            root._currentPath = "";
        }
    }
}
