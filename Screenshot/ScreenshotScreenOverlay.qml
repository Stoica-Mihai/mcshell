import QtQuick
import Quickshell
import Quickshell.Wayland
import Qs.DataControl
import qs.Config
import qs.Core

// One screenshot overlay per screen (instantiated via Variants by
// Screenshot/ScreenshotOverlay.qml). Instances are always visible and
// never switch screens — dynamically reassigning `screen` at runtime
// used to race with Qt's Wayland handleScreensChanged and segfault.
OverlayWindow {
    id: root
    namespace: Namespaces.screenshot
    // Must be on the absolute-top Overlay layer — the frozen selection UI
    // has to sit above every other mcshell surface.
    layer: WlrLayer.Overlay
    focusMode: WlrKeyboardFocus.None
    // Mask is managed imperatively below (see startCapture / _reset) —
    // override the parent's `active`-driven binding with an empty region
    // as the idle default.
    mask: Region {}
    anchors { top: true; bottom: true; left: true; right: true }

    property string mode: "" // "full" | "area"

    // Emitted on a successful save with the absolute path; consumers (e.g.
    // the xdg-desktop-portal Screenshot bridge in shell.qml) wrap into a
    // file:// URI to reply to the requester.
    signal captured(string filePath)
    signal captureFailed()
    // Area-mode cross-overlay coordination. Emitted by this overlay when
    // the user starts dragging here (so peers can disable themselves) and
    // when this overlay finishes/cancels (so peers can tear down too).
    signal areaClaimedHere()
    signal areaSessionFinished()

    property string _savePath: ""
    property string _tmpPath: ""
    property bool _captured: false
    property bool _captureActive: false // true after first capture, never reset
    // Set when a peer overlay claimed the area selection first. Hides the
    // rubber-band MouseArea so the user can't draw on two screens at once;
    // the dim backdrop stays so the freeze is visible.
    property bool _passive: false

    // Area selection state
    property real _startX: 0
    property real _startY: 0
    property real _selX: 0
    property real _selY: 0
    property real _selW: 0
    property real _selH: 0
    property bool _selecting: false
    readonly property bool _selectionReady: _selW > 2 && _selH > 2
    readonly property bool _active: mode !== ""

    Region { id: _emptyRegion }

    // ── Public API ──────────────────────────────────────
    function startCapture(captureMode) {
        _reset();
        mode = captureMode;
        _savePath = Theme.screenshotPrefix + Date.now() + ".png";
        // Per-screen tmp file: area mode broadcasts to all overlays in one
        // tick, so a shared path lets peers clobber each other's frame.
        _tmpPath = `${_savePath}.${root.screen.name}.tmp.png`;
        mask = null;

        // Fresh context on first use, else just request a new frame. Either
        // way captureView.frameReady fires when the frame lands → _onFrameReady
        // grabs exactly then (no timer, so never a stale frontbuffer).
        if (!_captureActive) _captureActive = true;
        else captureView.captureFrame();
        _timeout.start();
    }

    // Peer signalled it claimed the area selection — we go passive so the
    // user can only draw on one screen at a time.
    function setPassive() {
        if (root.mode === "area") root._passive = true;
    }

    // ── Internals ───────────────────────────────────────
    function _reset() {
        _captured = false;
        _selecting = false;
        _passive = false;
        _selX = 0; _selY = 0; _selW = 0; _selH = 0;
        _startX = 0; _startY = 0;
        cropImage.source = "";
    }

    // Tear-down. `broadcast=false` skips fan-out — used when called from
    // a peer's broadcast handler so we don't loop.
    function _close(broadcast) {
        if (!_active) return;
        const wasArea = mode === "area";
        mode = "";
        _reset();
        captureView.opacity = 0;
        mask = _emptyRegion;
        WlrLayershell.keyboardFocus = WlrKeyboardFocus.None;
        _timeout.stop();
        if (wasArea && broadcast !== false) root.areaSessionFinished();
    }

    function _onFrameReady() {
        if (_captured || mode === "") return;
        _captured = true;
        _timeout.stop();

        // Reveal the fresh frame for the grab (hidden during capture so the
        // overlay's own content isn't included).
        captureView.opacity = 1;

        captureView.grabToImage(function(result) {
            if (!result || !result.saveToFile(root._tmpPath)) {
                root._close();
                return;
            }
            if (root.mode === "full") {
                root._finishFullScreen();
            } else if (root.mode === "area") {
                root.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive;
                keyHandler.forceActiveFocus();
            }
        });
    }

    function _copyToClipboard(path) {
        ClipboardHistory.addFromFile(path, "image/png");
    }

    function _finishFullScreen() {
        _copyToClipboard(_tmpPath);
        Quickshell.execDetached({ command: ["mv", _tmpPath, _savePath] });
        NotificationDispatcher.sendWithImage("Screenshot", "Copied to clipboard", _savePath);
        captured(_savePath);
        _close();
    }

    function _grabSelection() {
        if (!_selectionReady) { _close(); return; }

        cropHelper.width = Math.round(_selW);
        cropHelper.height = Math.round(_selH);
        cropImage.x = -Math.round(_selX);
        cropImage.y = -Math.round(_selY);
        cropImage.width = root.width;
        cropImage.height = root.height;
        cropImage.source = "file://" + _tmpPath;
    }

    function _finishAreaCrop() {
        cropHelper.grabToImage(function(result) {
            if (result && result.saveToFile(root._savePath)) {
                root._copyToClipboard(root._savePath);
                Quickshell.execDetached({ command: ["rm", "-f", root._tmpPath] });
                NotificationDispatcher.sendWithImage("Screenshot", "Copied to clipboard", root._savePath);
                root.captured(root._savePath);
            } else {
                root.captureFailed();
            }
            root._close();
        });
    }

    // ── Timers ──────────────────────────────────────────
    Timer {
        id: _timeout
        interval: 3000
        onTriggered: {
            console.warn("[screenshot] capture timed out");
            root._close();
        }
    }

    Timer {
        id: _grabTimer
        interval: 50
        onTriggered: root._finishAreaCrop()
    }

    // ── Crop helper ─────────────────────────────────────
    Item {
        id: cropHelper
        clip: true

        Image {
            id: cropImage
            asynchronous: false
            fillMode: Image.Pad

            onStatusChanged: {
                if (status === Image.Ready && root.mode === "area")
                    _grabTimer.start();
            }
        }
    }

    // ── Screen capture ──────────────────────────────────
    // Context persists once created (destroying it crashes: a trailing
    // compositor event hits the freed zwlr_screencopy_frame). frameReady
    // (mcs-qs) fires per frame, so the grab waits for the real arrival.
    ScreencopyView {
        id: captureView
        anchors.fill: parent
        captureSource: root._captureActive ? root.screen : null
        paintCursor: false
        opacity: 0

        onFrameReady: root._onFrameReady()
    }

    // ── Area selection UI ───────────────────────────────
    Item {
        id: selectionUI
        anchors.fill: parent
        visible: root.mode === "area" && root._captured

        // Full dim while no selection drawn yet. Stays even when passive
        // (peer claimed) so the user still sees this screen is "frozen"
        // — only the rubber-band MouseArea is gated.
        Rectangle {
            anchors.fill: parent
            color: Theme.backdrop
            visible: root._selW === 0 && !root._selecting
        }

        Rectangle {
            width: parent.width
            height: Math.max(0, root._selY)
            color: Theme.backdrop
            visible: root._selW > 0
        }
        Rectangle {
            y: root._selY + root._selH
            width: parent.width
            height: Math.max(0, parent.height - root._selY - root._selH)
            color: Theme.backdrop
            visible: root._selW > 0
        }
        Rectangle {
            y: root._selY
            width: Math.max(0, root._selX)
            height: root._selH
            color: Theme.backdrop
            visible: root._selW > 0
        }
        Rectangle {
            x: root._selX + root._selW
            y: root._selY
            width: Math.max(0, parent.width - root._selX - root._selW)
            height: root._selH
            color: Theme.backdrop
            visible: root._selW > 0
        }

        Rectangle {
            x: root._selX
            y: root._selY
            width: root._selW
            height: root._selH
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            visible: root._selW > 0 && root._selH > 0
        }

        Rectangle {
            visible: root._selW > 0 && root._selH > 0
            x: Math.max(0, Math.min(root._selX + root._selW / 2 - width / 2, parent.width - width))
            y: Math.min(root._selY + root._selH + 8, parent.height - height - 4)
            width: sizeText.implicitWidth + 16
            height: sizeText.implicitHeight + 8
            radius: Theme.radiusSmall
            color: Theme.bg

            Text {
                id: sizeText
                anchors.centerIn: parent
                text: `${Math.round(root._selW)} \u00d7 ${Math.round(root._selH)}`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.fg
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 32
            width: legendText.implicitWidth + 16
            height: legendText.implicitHeight + 8
            radius: Theme.radiusSmall
            color: Theme.bg

            Text {
                id: legendText
                anchors.centerIn: parent
                text: root._selectionReady
                    ? Theme.legend("Space capture", Theme.hintEsc + " cancel")
                    : Theme.legend("Drag to select", Theme.hintEsc + " cancel")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.accent
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            // Disable interactions when a peer overlay claimed the area —
            // user only drags on one screen at a time. The dim backdrop
            // above stays visible so this screen still looks "frozen".
            enabled: !root._passive

            onPressed: mouse => {
                root._startX = mouse.x;
                root._startY = mouse.y;
                root._selX = mouse.x;
                root._selY = mouse.y;
                root._selW = 0;
                root._selH = 0;
                root._selecting = true;
                // First mousedown anywhere in the session wins. Tell peers
                // to disable themselves so the user can't draw on another
                // screen in parallel.
                root.areaClaimedHere();
            }

            onPositionChanged: mouse => {
                if (!root._selecting) return;
                root._selX = Math.min(root._startX, mouse.x);
                root._selY = Math.min(root._startY, mouse.y);
                root._selW = Math.abs(mouse.x - root._startX);
                root._selH = Math.abs(mouse.y - root._startY);
            }

            onReleased: {
                root._selecting = false;
            }
        }
    }

    // ── Keyboard handler ────────────────────────────────
    Item {
        id: keyHandler
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root._close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Space && root.mode === "area"
                       && root._selectionReady && !root._passive) {
                root._grabSelection();
                event.accepted = true;
            }
        }
    }
}
