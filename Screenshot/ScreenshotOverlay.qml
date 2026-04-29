import QtQuick
import Quickshell
import Quickshell.Io

// Screenshot dispatcher: owns one ScreenshotScreenOverlay per screen and
// routes captureFullScreen/captureArea to the overlay on the niri-focused
// output. Per-screen overlays keep their own `screen` binding fixed for
// their lifetime — reassigning a layer-shell surface's screen at runtime
// races with Qt's Wayland handleScreensChanged and segfaults (Qt 6.11).
//
// The focused-output is fetched synchronously per-dispatch via `niri msg`
// rather than read from FocusedOutput.name, because the Niri.workspaces
// IPC stream takes ~tens of ms to populate after shell startup. A fast
// user (or one whose first screenshot is the very first action after
// `make start`) would otherwise hit an empty name and the dispatcher
// would fall back to screens[0] — freezing the wrong monitor.
Item {
    id: root

    // ── Public API ──────────────────────────────────────
    function captureFullScreen() { _dispatch("full"); }
    function captureArea() { _dispatch("area"); }

    // Forwarded from the per-screen overlay that handled the capture.
    signal captured(string filePath)
    signal captureFailed()

    // ── Internals ───────────────────────────────────────
    signal _captureRequested(string targetScreen, string mode)

    property string _pendingMode: ""

    function _dispatch(mode) {
        _pendingMode = mode;
        _focusQuery.running = true;
    }

    Process {
        id: _focusQuery
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                try { name = JSON.parse(text).name || ""; } catch (e) {}
                root._captureRequested(name, root._pendingMode);
                root._pendingMode = "";
            }
        }
    }

    Variants {
        model: Quickshell.screens

        ScreenshotScreenOverlay {
            id: screenOverlay
            required property var modelData
            screen: modelData

            onCaptured: filePath => root.captured(filePath)
            onCaptureFailed: root.captureFailed()

            Connections {
                target: root
                function on_CaptureRequested(targetScreen, mode) {
                    const isTargeted = targetScreen
                        ? modelData.name === targetScreen
                        : modelData === Quickshell.screens[0];
                    if (isTargeted) screenOverlay.startCapture(mode);
                }
            }
        }
    }
}
