import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Widgets
import qs.QuickSettings

// Volume dropdown panel — anchored to the volume bar widget.
// Contains: main volume slider + per-app volume sliders.
AnimatedPopup {
    id: root

    implicitWidth: 280
    fullHeight: content.implicitHeight + 24

    // ── Background ──────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.barRadius
        bottomRightRadius: Theme.barRadius
        color: Theme.bgSolid
        border.width: 1
        border.color: Theme.border
        clip: true

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            height: 2
            color: Theme.bgSolid
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 4

            // ── Main volume ─────────────────────────────
            VolumeSlider {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
            }

            // ── Per-app volume ───────────────────────────
            Rectangle {
                visible: appVolume.hasStreams
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            AppVolume {
                id: appVolume
                Layout.fillWidth: true
            }
        }
    }
}
