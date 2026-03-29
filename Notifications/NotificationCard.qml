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
    required property int timeout

    signal dismissed(string notifId)

    // ── Sizing ────────────────────────────────────────────
    implicitWidth: parent ? parent.width : 360
    implicitHeight: bg.height
    clip: false

    // ── Slide-in on creation ─────────────────────────────
    property real slideX: implicitWidth + 20
    Component.onCompleted: slideX = 0;

    Behavior on slideX {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    readonly property bool countdownPaused: countdownItem.paused

    function pauseCountdown() { countdownItem.pause(); }
    function resumeCountdown() { countdownItem.resume(); }

    property bool _userDismissed: false

    // ── Animate-out: slide right off screen ──────────────
    function animateOut() {
        slideOutAnim.start();
    }

    function userClose() {
        _userDismissed = true;
        animateOut();
    }

    NumberAnimation {
        id: slideOutAnim
        target: card
        property: "slideX"
        to: card.implicitWidth + 20
        duration: 250
        easing.type: Easing.InCubic
        onFinished: card.dismissed(card.notifId)
    }

    // ── Card background ───────────────────────────────────
    Rectangle {
        id: bg
        x: card.slideX
        width: parent.width
        height: content.implicitHeight + 24
        radius: Theme.barRadius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border

        // Click anywhere to dismiss
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.userClose()
        }

        // Circular countdown — top-right, aligned with header
        Item {
            id: countdownItem
            width: 28
            height: 28
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 12

            property real fraction: 1.0
            property bool paused: false

            NumberAnimation {
                id: countdownAnim
                target: countdownItem
                property: "fraction"
                from: 1.0
                to: 0.0
                duration: card.timeout > 0 ? card.timeout : 5000
                easing.type: Easing.Linear
                running: true
                onFinished: card.animateOut()
            }

            function pause() { if (countdownAnim.running) { countdownAnim.pause(); paused = true; } }
            function resume() { if (countdownAnim.paused) { countdownAnim.resume(); paused = false; } }

            Canvas {
                anchors.fill: parent
                property real fraction: countdownItem.fraction
                property color ringColor: card.urgency === 2 ? Theme.red
                                        : card.urgency === 0 ? Theme.fgDim
                                        :                      Theme.accent
                onFractionChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    var cx = width / 2;
                    var cy = height / 2;
                    var r = Math.min(cx, cy) - 1.5;
                    var lineWidth = 2.5;

                    ctx.clearRect(0, 0, width, height);

                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.lineWidth = lineWidth;
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.1);
                    ctx.stroke();

                    if (fraction > 0) {
                        var startAngle = -Math.PI / 2;
                        var endAngle = startAngle + (2 * Math.PI * fraction);
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, startAngle, endAngle);
                        ctx.lineWidth = lineWidth;
                        ctx.strokeStyle = ringColor;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }
                }
            }

        }

        // ── Content ───────────────────────────────────────
        ColumnLayout {
            id: content
            anchors {
                top: parent.top
                left: parent.left
                right: countdownItem.left
                margins: 12
                rightMargin: 8
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
                    text: Theme.iconBell
                    font.family: Theme.iconFont
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

            // Large image preview (e.g. screenshot)
            Rectangle {
                id: previewContainer
                visible: previewImage.status === Image.Ready
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? width * 9 / 21 : 0
                Layout.topMargin: 4
                radius: 6
                color: "transparent"
                clip: true
                layer.enabled: true

                Image {
                    id: previewImage
                    anchors.fill: parent
                    source: {
                        const url = card.iconUrl || "";
                        // Strip image://icon/ wrapper to get raw file path
                        if (url.startsWith("image://icon//"))
                            return "file://" + url.substring("image://icon/".length);
                        if (url.startsWith("file://") || url.startsWith("/"))
                            return url;
                        return "";
                    }
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }

    }
}
