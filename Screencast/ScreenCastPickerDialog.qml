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

    /// Skew angle for the strip + inner dividers. Stronger than
    /// Theme.cardSkew (-0.03) so the picker reads as a single connected
    /// parallelogram, not a barely-tilted rectangle. Matches the skew
    /// used elsewhere for SkewPill / SkewTextField accents.
    readonly property real _stripSkew: -0.3

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

            BackgroundEffect.blurRegion: UserSettings.blurEnabled && root.activeRequest
                ? dialogBlurRegion : null
            Region { id: dialogBlurRegion; item: dialog; radius: Theme.dialogRadius }

            Rectangle {
                anchors.fill: parent
                color: Theme.backdrop
                opacity: root.activeRequest ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root._cancel()
                }
            }

            Keys.onEscapePressed: root._cancel()
            Keys.onReturnPressed: root._approve()

            Rectangle {
                id: dialog
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 760)
                implicitHeight: content.implicitHeight + Theme.dialogPadding * 2
                radius: Theme.dialogRadius
                // Theme.glassBg() honours the user's blur/transparency
                // setting — when blur is on, the wallpaper behind the
                // dialog is blurred (via BackgroundEffect.blurRegion
                // above) so there's no see-through "halo" effect. When
                // blur is off, glassBg falls back to a solid Theme.bg.
                color: Theme.glassBg()
                border.width: 1
                border.color: Theme.outlineVariant
                opacity: root.activeRequest ? 1 : 0
                scale: root.activeRequest ? 1 : 0.95

                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }
                Behavior on scale { NumberAnimation { duration: Theme.animSmooth; easing.type: Easing.OutCubic } }

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
                        // Inset just enough to keep the parallelogram's
                        // overhanging top-right / bottom-left corners off
                        // the dialog's rounded border. Combined with the
                        // ColumnLayout's 14px content margin this gives
                        // ~18px of total horizontal inset — a hair more
                        // than skewPx (≈ 17) so the corners clear the
                        // border with minimal visible perimeter padding.
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4

                        readonly property real skewAmount: root._stripSkew
                        readonly property real _skewPx: skewAmount * height / 2
                        readonly property int _count:
                            root.activeRequest?.availableSources?.length ?? 0
                        readonly property real _cellWidth:
                            _count > 0 ? width / _count : width

                        SkewRect {
                            anchors.fill: parent
                            // No interior fill — let the dialog background
                            // show through. Selection state on a chosen
                            // compartment paints accent over the same area.
                            fillColor: "transparent"
                            strokeColor: Theme.outline
                            strokeWidth: 1
                            skewAmount: strip.skewAmount
                        }

                        // Diagonal dividers between compartments. n-1 lines
                        // for n sources. Each line runs parallel to the
                        // outer skewed edges so the whole strip reads as
                        // one connected parallelogram with internal slots.
                        Repeater {
                            model: Math.max(0, strip._count - 1)
                            Shape {
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer
                                required property int index
                                readonly property real cx:
                                    strip._cellWidth * (index + 1)
                                ShapePath {
                                    strokeColor: Theme.outline
                                    strokeWidth: 1
                                    fillColor: "transparent"
                                    startX: cx - strip._skewPx
                                    startY: 0
                                    PathLine {
                                        x: cx + strip._skewPx
                                        y: strip.height
                                    }
                                }
                            }
                        }

                        // Compartment cells. Row inside the strip allocates
                        // equal-width cells; each cell hosts its own skewed
                        // selection fill + content + click handling.
                        Row {
                            anchors.fill: parent
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
                                        // Over-extend by 1px on every side to
                                        // swallow anti-aliased edge artifacts
                                        // where the cell's parallelogram fill
                                        // meets the strip's outer parallelogram
                                        // stroke. Without this the boundary
                                        // pixels read as "transparent padding".
                                        anchors.margins: -1
                                        visible: cell.selected
                                        // Higher-opacity tint so the selection
                                        // is unambiguously visible against the
                                        // dialog background.
                                        fillColor: Theme.withAlpha(Theme.accent, 0.22)
                                        strokeColor: "transparent"
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
                                            color: cell.selected ? Theme.accent : Theme.fg
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: cell.modelData.label || cell.modelData.id
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: cell.selected ? Theme.accent : Theme.fg
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

                                    // Only render the diamond on the chosen
                                    // compartment — empty diamonds on every
                                    // cell are visual noise, and the rightmost
                                    // one risks crowding the strip's outer
                                    // skewed edge.
                                    SkewCheck {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: 10
                                        anchors.rightMargin: 14
                                        visible: cell.selected
                                        checked: true
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
