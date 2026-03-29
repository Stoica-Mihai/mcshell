import QtQuick
import QtQuick.Layouts
import qs.Config

// Single notification card with fade-in/out animation and close button.
Item {
    id: card

    // ── Public interface ──────────────────────────────────
    required property string notifId
    required property string appName
    required property string summary
    required property string body
    required property string iconUrl
    required property int urgency

    signal dismissed(string notifId)

    // ── Sizing ────────────────────────────────────────────
    implicitWidth: parent ? parent.width : 360
    implicitHeight: bg.height

    // ── Fade-in on creation ───────────────────────────────
    opacity: 0
    scale: 0.92
    Component.onCompleted: {
        opacity = 1;
        scale = 1;
    }

    Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // ── Animate-out, then emit dismissed ──────────────────
    function animateOut() {
        opacity = 0;
        scale = 0.92;
        removeTimer.start();
    }

    Timer {
        id: removeTimer
        interval: 250
        onTriggered: card.dismissed(card.notifId)
    }

    // ── Card background ───────────────────────────────────
    Rectangle {
        id: bg
        width: parent.width
        height: content.implicitHeight + 24
        radius: Theme.barRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border

        // Urgency accent bar at top
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: Theme.barRadius
            anchors.rightMargin: Theme.barRadius
            height: 2
            radius: 1
            color: card.urgency === 2 ? Theme.red
                 : card.urgency === 0 ? Theme.fgDim
                 :                      Theme.accent
        }

        // ── Content ───────────────────────────────────────
        ColumnLayout {
            id: content
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 12
            }
            spacing: 4

            // Header row: icon + app name + close button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // App icon (Nerd Font bell fallback)
                Text {
                    id: iconFallback
                    visible: !iconImage.visible
                    text: "\uf0f3"  // nf-fa-bell
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }

                Image {
                    id: iconImage
                    source: card.iconUrl
                    visible: status === Image.Ready
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 16
                    sourceSize.height: 16
                }

                // App name
                Text {
                    text: card.appName || "Notification"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // Close button (X)
                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"  // nf-fa-close / nf-fa-xmark
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 12
                        color: closeArea.containsMouse ? Theme.red : Theme.fgDim
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.animateOut()
                    }
                }
            }

            // Summary
            Text {
                visible: text.length > 0
                text: card.summary
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Body
            Text {
                visible: text.length > 0
                text: card.body
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 4
                elide: Text.ElideRight
                Layout.fillWidth: true
                opacity: 0.85
            }
        }
    }
}
