import QtQuick
import Quickshell
import qs.Core

// Screenshot dispatcher: owns one ScreenshotScreenOverlay per screen and
// routes captureFullScreen/captureArea to the overlay on the niri-focused
// output. Per-screen overlays keep their own `screen` binding fixed for
// their lifetime — reassigning a layer-shell surface's screen at runtime
// races with Qt's Wayland handleScreensChanged and segfaults (Qt 6.11).
//
// Focused-output read from the FocusedOutput singleton (derived from
// Niri.workspaces). The previous per-dispatch `niri msg -j` fork is gone.
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

    function _dispatch(mode) {
        root._captureRequested(FocusedOutput.name, mode);
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
