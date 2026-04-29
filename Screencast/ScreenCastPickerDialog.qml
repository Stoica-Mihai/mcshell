import QtQuick
import QtQuick.Layouts
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
// Mirrors BluetoothPairingDialog: Variants over Quickshell.screens, an
// always-active layer-shell overlay per screen with a backdrop +
// centered glass dialog. Each available source becomes a card with a
// live ScreencopyView preview; click to select, confirm to approve.
//
// Multi-select is enabled only when the requesting app asks for it
// (`req.multiple`). Single-select is the common case (Firefox /
// Chrome / OBS pick one monitor at a time).
Item {
    id: root

    property var activeRequest: null
    property var _selectedIds: []

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

    // Map a source id ("output:NAME") back to a Quickshell screen so
    // the card can host a live ScreencopyView preview of it.
    function _screenForId(id) {
        if (!id || !id.startsWith("output:")) return null;
        const name = id.substring(7);
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === name) return list[i];
        }
        return null;
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
                    onClicked: root._cancel()  // click outside dialog cancels
                }
            }

            Keys.onEscapePressed: root._cancel()
            Keys.onReturnPressed: root._approve()

            Rectangle {
                id: dialog
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 720)
                implicitHeight: content.implicitHeight + Theme.dialogPadding * 2
                radius: Theme.dialogRadius
                color: Theme.glassBg()
                border.width: 1
                border.color: Theme.outlineVariant
                opacity: root.activeRequest ? 1 : 0
                scale: root.activeRequest ? 1 : 0.95

                Behavior on opacity { NumberAnimation { duration: Theme.animSmooth } }
                Behavior on scale { NumberAnimation { duration: Theme.animSmooth; easing.type: Easing.OutCubic } }

                MouseArea { anchors.fill: parent; onClicked: {} }  // swallow

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: Theme.dialogPadding
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
                            const app = root.activeRequest.appId || "An application";
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

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        columns: Math.max(1, Math.min(
                            (root.activeRequest?.availableSources?.length ?? 1), 3))
                        columnSpacing: Theme.spacingMedium
                        rowSpacing: Theme.spacingMedium

                        Repeater {
                            model: root.activeRequest?.availableSources ?? []

                            Rectangle {
                                id: card
                                required property var modelData
                                readonly property bool selected:
                                    root._selectedIds.indexOf(modelData.id) >= 0
                                readonly property var screenObj:
                                    root._screenForId(modelData.id)

                                Layout.fillWidth: true
                                Layout.preferredHeight: 160
                                radius: 8
                                color: Theme.withAlpha(Theme.fg, 0.04)
                                border.width: card.selected ? 2 : 1
                                border.color: card.selected ? Theme.accent : Theme.outlineVariant

                                Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

                                ScreencopyView {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    captureSource: card.screenObj
                                    paintCursor: false
                                    live: false
                                    visible: card.screenObj !== null
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    height: labelText.implicitHeight + 10
                                    color: Theme.withAlpha(Theme.bg, 0.7)
                                    radius: 0

                                    Text {
                                        id: labelText
                                        anchors.centerIn: parent
                                        text: card.modelData.label || card.modelData.id
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }

                                SkewCheck {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    checked: card.selected
                                    size: 16
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._toggle(card.modelData.id)
                                    onDoubleClicked: {
                                        root._toggle(card.modelData.id);
                                        root._approve();
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

                        TextButton {
                            label: "Cancel"
                            onClicked: root._cancel()
                        }
                        TextButton {
                            label: "Share"
                            enabled: root._selectedIds.length > 0
                            onClicked: root._approve()
                        }
                    }
                }
            }
        }
    }
}
