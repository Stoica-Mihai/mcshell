import QtQuick
import Quickshell
import qs.Core

// Screenshot dispatcher: owns one ScreenshotScreenOverlay per screen and
// routes captureFullScreen/captureArea to the overlay on the niri-focused
// output. Per-screen overlays keep their own `screen` binding fixed for
// their lifetime — reassigning a layer-shell surface's screen at runtime
// races with Qt's Wayland handleScreensChanged and segfaults (Qt 6.11).
Item {
    id: root

    // ── Public API ──────────────────────────────────────
    function captureFullScreen() { _dispatch("full"); }
    function captureArea() { _dispatch("area"); }

    // ── Internals ───────────────────────────────────────
    // Targeted screen name is broadcast — each ScreenshotScreenOverlay
    // filters on its own screen.name. Empty target means "first screen".
    signal _captureRequested(string targetScreen, string mode)

    function _dispatch(mode) {
        _captureRequested(FocusedOutput.name, mode);
    }

    Variants {
        model: Quickshell.screens

        ScreenshotScreenOverlay {
            required property var modelData
            screen: modelData

            Connections {
                target: root
                function on_CaptureRequested(targetScreen, mode) {
                    const isTargeted = targetScreen
                        ? modelData.name === targetScreen
                        : modelData === Quickshell.screens[0];
                    if (isTargeted) startCapture(mode);
                }
            }
        }
    }
}
