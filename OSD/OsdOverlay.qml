import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.Config
import qs.Core


Variants {
    id: osd

    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: overlay

            required property var modelData
            screen: modelData

            // ── State ──────────────────────────────────────────
            readonly property PwNode sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
            readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)
            readonly property bool muted: sink?.audio?.muted ?? false
            readonly property int brightness: Brightness.value
            readonly property int brightnessMax: Brightness.max

            // Track previous values for change detection
            property int prevVolume: -1
            property bool prevMuted: false

            // Which indicator to show: "volume" | "brightness" | ""
            property string activeType: ""

            // Suppress OSD during initial read
            property bool startupDone: false

            PwObjectTracker {
                objects: overlay.sink ? [overlay.sink] : []
            }

            // React to volume changes instantly via binding
            onVolumeChanged: {
                if (!startupDone) { prevVolume = volume; return; }
                if (volume !== prevVolume) {
                    prevVolume = volume;
                    activeType = "volume";
                    showOsd();
                }
            }

            onMutedChanged: {
                if (!startupDone) { prevMuted = muted; return; }
                if (muted !== prevMuted) {
                    prevMuted = muted;
                    activeType = "volume";
                    showOsd();
                }
            }

            // ── Dimensions ─────────────────────────────────────
            readonly property int osdWidth: 280
            readonly property int osdHeight: 56

            implicitWidth: osdWidth
            implicitHeight: osdHeight
            color: "transparent"
            visible: false

            // ── Wayland layer setup ────────────────────────────
            WlrLayershell.namespace: "mcshell-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            // Center-bottom positioning
            anchors {
                bottom: true
                left: true
                right: true
            }
            margins.bottom: 60

            // Click-through: OSD is display-only
            mask: Region {}

            // ── Brightness change detection (via Brightness singleton) ──
            Connections {
                target: Brightness
                function onChanged() {
                    if (overlay.startupDone) {
                        overlay.activeType = "brightness";
                        overlay.showOsd();
                    }
                }
            }

            // ── Startup guard ──────────────────────────────────
            // Let initial values settle before showing OSD
            Timer {
                id: startupGuard
                interval: 1500
                running: true
                onTriggered: overlay.startupDone = true
            }

            // ── Auto-hide timer ────────────────────────────────
            Timer {
                id: hideTimer
                interval: 2000
                onTriggered: overlay.hideOsd()
            }

            // ── Show / hide logic ──────────────────────────────
            function showOsd() {
                hideTimer.stop();
                overlay.visible = true;
                osdBody.opacity = 1.0;
                osdBody.scale = 1.0;
                hideTimer.start();
            }

            function hideOsd() {
                osdBody.opacity = 0.0;
                osdBody.scale = 0.92;
                hideFinish.start();
            }

            Timer {
                id: hideFinish
                interval: 250
                onTriggered: {
                    overlay.visible = false;
                    overlay.activeType = "";
                }
            }

            // ── Computed display values ────────────────────────
            readonly property string displayIcon: {
                if (activeType === "volume")
                    return Theme.volumeIcon(volume / 100, muted);
                if (activeType === "brightness")
                    return Theme.iconBrightness;
                return "";
            }

            readonly property real displayFraction: {
                if (activeType === "volume")
                    return Math.min(1.0, volume / 100);
                if (activeType === "brightness")
                    return brightnessMax > 0 ? Math.min(1.0, brightness / brightnessMax) : 0;
                return 0;
            }

            readonly property string displayPercent: {
                if (activeType === "volume")
                    return volume + "%";
                if (activeType === "brightness")
                    return Math.round(displayFraction * 100) + "%";
                return "";
            }

            readonly property color iconColor: {
                if (activeType === "volume" && muted)
                    return Theme.red;
                return Theme.fg;
            }

            readonly property color barColor: {
                if (activeType === "volume" && muted)
                    return Theme.red;
                return Theme.accent;
            }

            // ── Visual ─────────────────────────────────────────
            Item {
                id: osdBody
                anchors.centerIn: parent
                width: overlay.osdWidth
                height: overlay.osdHeight
                opacity: 0
                scale: 0.92

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animSmooth
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animSmooth
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: bg
                    anchors.fill: parent
                    radius: Theme.barRadius
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    // Icon (Nerd Font)
                    Text {
                        id: icon
                        text: overlay.displayIcon
                        color: overlay.iconColor
                        font.family: Theme.iconFont
                        font.pixelSize: 20
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color {
                            ColorAnimation { duration: Theme.animSmooth }
                        }
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        height: 6
                        radius: 3
                        color: Theme.fgDim

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * overlay.displayFraction
                            radius: parent.radius
                            color: overlay.barColor

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.animNormal
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on color {
                                ColorAnimation { duration: Theme.animSmooth }
                            }
                        }
                    }

                    // Percentage text
                    Text {
                        text: overlay.displayPercent
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 40
                    }
                }
            }
        }
    }
}
