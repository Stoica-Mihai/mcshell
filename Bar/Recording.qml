import QtQuick
import Quickshell
import Quickshell.Io
import Qs.DataControl
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
            // wf-recorder prompts interactively when more than one output
            // exists and -o isn't supplied; with no stdin attached it
            // immediately exits 2. Always pass -o so a multi-monitor setup
            // doesn't hit that. Fall back to the first available screen
            // when FocusedOutput hasn't populated yet (Recording is in a
            // Loader that instantiates lazily — niri IPC may not have
            // produced workspace data on the very first toggle).
            let output = FocusedOutput.name;
            if (!output) {
                const screens = Quickshell.screens;
                if (screens && screens.length > 0) output = screens[0].name;
            }
            if (!output) {
                console.warn("[mcshell] Recording: no output to capture");
                NotificationDispatcher.send("Recording failed", "no output to capture", 5000);
                root._currentPath = "";
                return;
            }
            recorder.command = ["wf-recorder", "-o", output, "-f", root._currentPath];
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
