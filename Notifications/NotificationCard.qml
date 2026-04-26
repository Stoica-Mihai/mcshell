import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Widgets

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
    required property bool hasActions
    required property bool hasInlineReply

    readonly property bool replyFocused: replyField.activeFocus

    // Function to look up the notification object (set by parent)
    property var getNotifRef: function() { return null; }

    signal dismissed(string notifId)

    // ── Sizing ────────────────────────────────────────────
    implicitWidth: parent ? parent.width : 360
    implicitHeight: bg.height
    clip: false

    // ── Slide-in on creation ─────────────────────────────
    property real slideX: implicitWidth + 20
    Component.onCompleted: slideX = 0;

    Behavior on slideX {
        NumberAnimation { duration: Theme.animSmooth; easing.type: Easing.OutCubic }
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
        duration: Theme.animSmooth
        easing.type: Easing.InCubic
        onFinished: card.dismissed(card.notifId)
    }

    // ── Card background ───────────────────────────────────
    Rectangle {
        id: bg
        x: card.slideX
        width: parent.width
        height: content.implicitHeight + Theme.popupPadding * 2
        radius: Theme.barRadius
        color: Theme.glassBg()
        border.width: 1
        border.color: Theme.border

        // Click to dismiss (but not on interactive elements)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const pos = replyContainer.mapFromItem(this, mouse.x, mouse.y);
                if (replyContainer.visible && replyContainer.contains(pos)) {
                    replyField.forceActiveFocus();
                } else {
                    card.userClose();
                }
            }
        }

        // Circular countdown — top-right, aligned with header
        Item {
            id: countdownItem
            width: 28
            height: 28
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingLarge
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingLarge

            property real fraction: 1.0
            property bool paused: false

            NumberAnimation {
                id: countdownAnim
                target: countdownItem
                property: "fraction"
                from: 1.0
                to: 0.0
                duration: card.timeout > 0 ? card.timeout : Theme.notifDefaultTimeout
                easing.type: Easing.Linear
                running: true
                onFinished: card.animateOut()
            }

            function pause() { if (countdownAnim.running) { countdownAnim.pause(); paused = true; } }
            function resume() { if (countdownAnim.paused) { countdownAnim.resume(); paused = false; } }

            Canvas {
                anchors.fill: parent
                property real fraction: countdownItem.fraction
                property color ringColor: Theme.urgencyColor(card.urgency)
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
                    ctx.strokeStyle = Theme.withAlpha(Theme.fg, 0.1);
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
                margins: Theme.popupPadding
                rightMargin: Theme.spacingNormal
            }
            spacing: Theme.spacingTiny

            // Header row: icon + app name
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingNormal

                // App icon (Nerd Font bell fallback)
                Text {
                    id: iconFallback
                    visible: !iconImage.visible
                    text: Theme.iconBell
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }

                OptImage {
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
                textFormat: Text.PlainText
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
                textFormat: Text.PlainText
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 4
                elide: Text.ElideRight
                Layout.fillWidth: true
                opacity: Theme.opacityBody
            }

            // Action buttons
            Flow {
                id: actionRow
                visible: card.hasActions
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: Theme.spacingSmall

                property var actionList: {
                    if (!card.hasActions) return [];
                    const ref = card.getNotifRef();
                    if (!ref || !ref.actions) return [];
                    const list = [];
                    for (let i = 0; i < ref.actions.length; i++)
                        list.push({ identifier: ref.actions[i].identifier, text: ref.actions[i].text });
                    return list;
                }

                Repeater {
                    model: actionRow.actionList

                    Rectangle {
                        required property var modelData

                        width: actionLabel.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: actionMouse.containsMouse ? Theme.overlayHover : Theme.overlay

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTiny
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const ref = card.getNotifRef();
                                if (ref && ref.actions) {
                                    for (let i = 0; i < ref.actions.length; i++) {
                                        if (ref.actions[i].identifier === modelData.identifier) {
                                            ref.actions[i].invoke();
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Inline reply
            Rectangle {
                id: replyContainer
                visible: card.hasInlineReply
                Layout.fillWidth: true
                Layout.topMargin: 4
                height: 28
                radius: Theme.radiusSmall
                color: Theme.bgSolid
                border.width: 1
                border.color: replyField.activeFocus ? Theme.accent : Theme.border

                TextInput {
                    id: replyField
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingNormal
                    anchors.rightMargin: Theme.spacingNormal
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fg
                    clip: true

                    Keys.onReturnPressed: {
                        if (text.trim() !== "") {
                            const ref = card.getNotifRef();
                            if (ref) ref.sendInlineReply(text);
                            card.animateOut();
                        }
                    }
                    Keys.onEscapePressed: card.userClose()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Type a reply..."
                        color: Theme.fgDim
                        font: parent.font
                        visible: !parent.text && !parent.activeFocus
                    }
                }
            }

            // Large image preview (e.g. screenshot)
            Rectangle {
                id: previewContainer
                visible: previewImage.status === Image.Ready
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? width * 9 / 21 : 0
                Layout.topMargin: 4
                radius: Theme.radiusSmall
                color: Theme.bgSolid
                clip: true

                OptImage {
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
                }
            }
        }

    }
}
