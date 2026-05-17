import QtQuick
import Quickshell
import qs.Core

// Screenshot dispatcher: owns one ScreenshotScreenOverlay per screen.
//
// `full` mode targets the niri-focused output (one screen captured).
// `area` mode is broadcast: every overlay freezes its own screen, the
// user can start the drag on any one. First mousedown wins; the other
// screens go passive (still dimmed, but no rubber-band). Whichever
// screen finishes — Space to capture, Escape to cancel — broadcasts a
// close so everyone tears down at once.
//
// Per-screen overlays keep their own `screen` binding fixed for their
// lifetime — reassigning a layer-shell surface's screen at runtime
// races with Qt's Wayland handleScreensChanged and segfaults (Qt 6.11).
Item {
    id: root

    // ── Public API ──────────────────────────────────────
    function captureFullScreen() { _dispatch("full"); }
    function captureArea() { _dispatch("area"); }

    // Forwarded from the per-screen overlay that handled the capture.
    signal captured(string filePath)
    signal captureFailed()

    // ── Internals ───────────────────────────────────────
    // targetScreen="" broadcasts (used for area). For full it carries the
    // focused output's name so only that overlay activates.
    signal _captureRequested(string targetScreen, string mode)
    // Emitted by whichever overlay catches the first mousedown in area
    // mode. Other overlays observe and disable their own rubber-band.
    signal _areaClaimed(string screenName)
    // Broadcast tear-down. Every overlay calls _close() in response; no
    // re-emit so we don't loop.
    signal _allClose()

    function _dispatch(mode) {
        const target = mode === "area" ? "" : FocusedOutput.name;
        root._captureRequested(target, mode);
    }

    Variants {
        model: Quickshell.screens

        ScreenshotScreenOverlay {
            id: screenOverlay
            required property var modelData
            screen: modelData

            onCaptured: filePath => root.captured(filePath)
            onCaptureFailed: root.captureFailed()
            onAreaSessionFinished: root._allClose()
            onAreaClaimedHere: root._areaClaimed(modelData.name)

            Connections {
                target: root
                function on_CaptureRequested(targetScreen, mode) {
                    const isTargeted = !targetScreen || modelData.name === targetScreen;
                    if (isTargeted) screenOverlay.startCapture(mode);
                }
                function on_AreaClaimed(screenName) {
                    if (modelData.name !== screenName) screenOverlay.setPassive();
                }
                function on_AllClose() {
                    screenOverlay._close(false);
                }
            }
        }
    }
}
