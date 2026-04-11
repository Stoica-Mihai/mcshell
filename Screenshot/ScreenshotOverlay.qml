import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._DataControl
import qs.Config
import qs.Core

PanelWindow {
    id: root
    // Always visible — WlrLayershell destroys the QQuickWindow on hide
    // (deleteOnInvisible), invalidating scene graph state. Use mask for
    // click-through and opacity for content visibility instead.
    visible: true
    color: "transparent"
    mask: Region {}
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "mcshell-screenshot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    property string mode: "" // "full" | "area"
    property string _savePath: ""
    property string _tmpPath: ""
    property bool _captured: false
    property bool _captureActive: false // true after first capture, never reset
    property var _emptyRegion: null

    // Area selection state
    property real _startX: 0
    property real _startY: 0
    property real _selX: 0
    property real _selY: 0
    property real _selW: 0
    property real _selH: 0
    property bool _selecting: false
    readonly property bool _selectionReady: _selW > 2 && _selH > 2

    Component.onCompleted: {
        _emptyRegion = Qt.createQmlObject('import Quickshell; Region {}', root);
    }

    property string _pendingMode: ""

    // ── Public API ──────────────────────────────────────
    function captureFullScreen() { _startCapture("full"); }
    function captureArea() { _startCapture("area"); }

    function _startCapture(captureMode) {
        _pendingMode = captureMode;
        _outputDetect.running = true;
    }

    Process {
        id: _outputDetect
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const name = JSON.parse(this.text).name;
                    for (const s of Quickshell.screens) {
                        if (s.name === name && root.screen !== s) {
                            // Invalidate capture context before switching screen
                            // to avoid stale wl_output proxy crash
                            root._captureActive = false;
                            root.screen = s;
                            break;
                        }
                    }
                } catch(e) {}
                root._beginCapture(root._pendingMode);
            }
        }
    }

    function _beginCapture(captureMode) {
        _reset();
        mode = captureMode;
        _savePath = Theme.screenshotPrefix + Date.now() + ".png";
        _tmpPath = _savePath + ".tmp.png";
        mask = null;
        // Don't set captureView.opacity yet — capture the clean screen
        // first, then show the new frame in _onFrameReady.

        if (!_captureActive) {
            // First capture ever: activate the ScreencopyView.
            // createContext() auto-calls captureFrame() and hasContentChanged
            // fires when the frame arrives (false→true).
            _captureActive = true;
        } else {
            // Subsequent: context persists, just request a new frame.
            // swapBuffers() in the response changes presentSecondBuffer,
            // so syncSwapchain() recreates the texture (no early-return).
            captureView.captureFrame();
            _frameDelay.start();
        }
        _timeout.start();
    }

    // ── Internals ───────────────────────────────────────
    function _reset() {
        _captured = false;
        _selecting = false;
        _selX = 0; _selY = 0; _selW = 0; _selH = 0;
        _startX = 0; _startY = 0;
        cropImage.source = "";
    }

    function _close() {
        mode = "";
        _reset();
        captureView.opacity = 0;
        mask = _emptyRegion;
        WlrLayershell.keyboardFocus = WlrKeyboardFocus.None;
        _timeout.stop();
        _frameDelay.stop();
    }

    function _onFrameReady() {
        if (_captured || mode === "") return;
        _captured = true;
        _timeout.stop();
        _frameDelay.stop();

        // Show the fresh frame now (not before capture, to avoid
        // the overlay's stale content being included in the capture)
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
        id: _frameDelay
        interval: 100
        onTriggered: root._onFrameReady()
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
    // captureSource is null until first capture, then stays set forever.
    // Context + buffers persist across captures — no destruction, no wl_proxy errors.
    // Opacity hides stale content between captures.
    ScreencopyView {
        id: captureView
        anchors.fill: parent
        captureSource: root._captureActive ? root.screen : null
        paintCursor: false
        opacity: 0

        onHasContentChanged: {
            if (hasContent) root._onFrameReady();
        }
    }

    // ── Area selection UI ───────────────────────────────
    Item {
        id: selectionUI
        anchors.fill: parent
        visible: root.mode === "area" && root._captured

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

            onPressed: mouse => {
                root._startX = mouse.x;
                root._startY = mouse.y;
                root._selX = mouse.x;
                root._selY = mouse.y;
                root._selW = 0;
                root._selH = 0;
                root._selecting = true;
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
                       && root._selectionReady) {
                root._grabSelection();
                event.accepted = true;
            }
        }
    }
}
