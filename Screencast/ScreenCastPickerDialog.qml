import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Portal
import qs.Config
import qs.Core
import qs.Widgets

// ScreenCast portal picker. Renders an overlay on every screen when the
// portal emits `pickerRequested` — apps go through `getDisplayMedia` /
// xdg-desktop-portal frontend → mcs-qs ScreenCastImpl → here.
//
// Layout follows the shell's skewed-morphism vocabulary: a single
// horizontal SkewRect strip subdivides into one compartment per source,
// with diagonal dividers matching the same skew angle as the outer
// chrome (mirroring the SkewTextField lock-icon / eye-icon idiom).
//
// Multi-select honours `req.multiple`; single-select is the common case
// (Firefox / Chrome / OBS each pick one monitor at a time).
Item {
    id: root

    property var activeRequest: null
    property var _selectedIds: []

    /// Shared skew angle for the dialog chrome AND compartments so all
    /// slanted edges run parallel. -0.12 is the compromise between a
    /// visible parallelogram on the compartments (skewPx ≈ 7 at 110px
    /// height) and a not-overwhelming lean on the wider/taller dialog
    /// chrome (skewPx ≈ 22 at ~370px height).
    readonly property real _stripSkew: -0.12

    Connections {
        target: ScreenCastPortal
        function onPickerRequested(req) {
            // If a previous request is still around, fail it — the portal
            // frontend never sends two simultaneous picks for the same
            // session, but a stale one shouldn't block the new prompt.
            if (root.activeRequest && !root.activeRequest.answered) {
                root.activeRequest.fail();
            }
            root._selectedIds = [];
            root.activeRequest = req;
            req.answeredChanged.connect(() => {
                if (req.answered && root.activeRequest === req)
                    root.activeRequest = null;
            });
        }
    }

    function _toggle(id) {
        const cur = root._selectedIds.slice();
        const i = cur.indexOf(id);
        if (i >= 0) cur.splice(i, 1);
        else if (root.activeRequest && root.activeRequest.multiple) cur.push(id);
        else { cur.length = 0; cur.push(id); }
        root._selectedIds = cur;
    }

    function _approve() {
        if (!root.activeRequest || root._selectedIds.length === 0) return;
        root.activeRequest.setSelectedSourceIds(root._selectedIds);
        root.activeRequest.approve();
    }

    function _cancel() {
        if (root.activeRequest) root.activeRequest.cancel();
    }

    Variants {
        model: Quickshell.screens

        OverlayWindow {
            id: overlay
            namespace: "mcshell-screencast-picker"
            active: root.activeRequest !== null

            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }

            // Match the AppLauncher pattern: when blur is on, the blur
            // region covers the entire screen (via the backdrop) and the
            // backdrop itself goes transparent so the wallpaper-blur
            // extends edge-to-edge. Through the dialog's translucency
            // you then see uniformly blurred wallpaper, not mixed
            // backdrop-dim + app windows behind. When blur is off, the
            // backdrop reverts to the dim black overlay.
            BackgroundEffect.blurRegion: UserSettings.blurEnabled && root.activeRequest
                ? backdropBlurRegion : null
            Region { id: backdropBlurRegion; item: pickerBackdrop }

            Rectangle {
                id: pickerBackdrop
                anchors.fill: parent
                color: UserSettings.blurEnabled ? "transparent" : Theme.backdrop
                opacity: root.activeRequest ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root._cancel()
                }
            }

            Keys.onEscapePressed: root._cancel()
            Keys.onReturnPressed: root._approve()

            Item {
                id: dialog
                anchors.centerIn: parent
                width: Math.min(parent.width - 120, 760)
                implicitHeight: content.implicitHeight + 40
                opacity: root.activeRequest ? 1 : 0
                scale: root.activeRequest ? 1 : 0.95

                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }
                Behavior on scale { NumberAnimation { duration: Theme.animSmooth; easing.type: Easing.OutCubic } }

                // Dialog chrome shares the strip's skew angle so the
                // dialog's left/right slants run parallel to each
                // compartment's left/right slants.
                SkewRect {
                    anchors.fill: parent
                    fillColor: Theme.glassBg()
                    strokeColor: Theme.outlineVariant
                    strokeWidth: 1
                    skewAmount: root._stripSkew
                }

                MouseArea { anchors.fill: parent; onClicked: {} } // swallow

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: Theme.spacingMedium

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Theme.iconMonitor
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSizeLarge
                        color: Theme.accent
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Share Your Screen"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: Theme.fg
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!root.activeRequest) return "";
                            // Most browsers report an opaque sandbox token like
                            // "sh" or empty as the appId — surfacing that adds
                            // no signal. Only show a name when the caller
                            // supplied something that looks app-like.
                            const raw = (root.activeRequest.appId || "").trim();
                            const looksReal = raw.length >= 3 && raw.indexOf('.') >= 0;
                            const app = looksReal ? raw : "An application";
                            const verb = root.activeRequest.multiple
                                ? "wants to share one or more screens."
                                : "wants to share a screen.";
                            return `${app} ${verb}`;
                        }
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    // ── The compartment strip ─────────────────────────────
                    // One horizontal SkewRect divided into N compartments
                    // (one per source) with diagonal dividers matching the
                    // outer skew angle. Each compartment is a clickable
                    // selection cell with its own skewed selection fill.
                    Item {
                        id: strip
                        Layout.fillWidth: true
                        Layout.preferredHeight: 110
                        Layout.topMargin: 6
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4

                        readonly property real skewAmount: root._stripSkew
                        readonly property real _skewPx: skewAmount * height / 2
                        readonly property int _count:
                            root.activeRequest?.availableSources?.length ?? 0
                        readonly property int _spacing: 14
                        // Each compartment width = (strip - gaps) / count.
                        readonly property real _cellWidth: _count > 0
                            ? (width - (_count - 1) * _spacing) / _count
                            : width

                        // Each compartment is now a standalone parallelogram
                        // with its own outline + selection fill, separated by
                        // _spacing pixels of gap. No outer strip outline and
                        // no dividers — the gaps and the per-cell strokes do
                        // the visual separation work.
                        Row {
                            anchors.fill: parent
                            spacing: strip._spacing

                            Repeater {
                                model: root.activeRequest?.availableSources ?? []
                                Item {
                                    id: cell
                                    required property var modelData
                                    readonly property bool selected:
                                        root._selectedIds.indexOf(modelData.id) >= 0
                                    width: strip._cellWidth
                                    height: strip.height

                                    SkewRect {
                                        anchors.fill: parent
                                        // Selection is signalled only by
                                        // the diamond at the top-right. No
                                        // fill / stroke / text colour change.
                                        fillColor: "transparent"
                                        strokeColor: Theme.outline
                                        strokeWidth: 1
                                        skewAmount: strip.skewAmount
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Theme.iconMonitor
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSizeMedium
                                            color: Theme.fg
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: cell.modelData.label || cell.modelData.id
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.fg
                                            elide: Text.ElideMiddle
                                            width: cell.width - 24
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: cell.modelData.width > 0
                                                ? `${cell.modelData.width} × ${cell.modelData.height}`
                                                : ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeMini
                                            color: Theme.fgDim
                                        }
                                    }

                                    // Always visible; empty (outline only)
                                    // when unselected, filled with the
                                    // theme accent when this monitor is
                                    // the active choice.
                                    SkewCheck {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: 10
                                        anchors.rightMargin: 14
                                        checked: cell.selected
                                        size: 14
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root._toggle(cell.modelData.id)
                                        onDoubleClicked: {
                                            root._toggle(cell.modelData.id);
                                            root._approve();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        text: root.activeRequest?.multiple
                            ? "Click to toggle. Double-click to share immediately."
                            : "Click to choose. Double-click to share immediately."
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMini
                        horizontalAlignment: Text.AlignHCenter
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        spacing: Theme.spacingMedium

                        SkewButton {
                            label: "Cancel"
                            onClicked: root._cancel()
                        }
                        SkewButton {
                            label: "Share"
                            primary: true
                            enabled: root._selectedIds.length > 0
                            onClicked: root._approve()
                        }
                    }
                }
            }
        }
    }
}
