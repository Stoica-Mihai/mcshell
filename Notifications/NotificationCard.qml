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
    required property string appIconUrl
    required property string imageUrl
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

    ParallelogramCard {
        id: bg
        x: card.slideX
        width: parent.width
        height: content.implicitHeight + Theme.popupPadding * 2
        // Opaque so the rectangular Wayland blur region (polygon blur
        // stair-steps via QRegion rasterization) doesn't leak through
        // and make the slanted countdown line look non-parallel.
        backgroundColor: Theme.bg
        showBorder: false
        skew: -0.10

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

        // ── Content ───────────────────────────────────────
        ColumnLayout {
            id: content
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.popupPadding
                // Extra clearance from the countdown line on the left edge
                leftMargin: Theme.popupPadding + Theme.spacingNormal
            }
            spacing: Theme.spacingTiny

            // Header row: mcshell brand mark + sender app icon + app name
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingNormal

                // Permanent mcshell logo — every notification carries the brand
                McshellLogo {
                    size: 16
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                }

                // Sender app icon — shown only when the notification supplied one
                OptImage {
                    id: iconImage
                    source: card.appIconUrl
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

            // Image preview — narrowed and centered so the parallelogram's
            // bottom-right slant doesn't clip into it.
            Rectangle {
                id: previewContainer
                visible: previewImage.status === Image.Ready
                Layout.preferredWidth: parent.width - 2 * bg.absSkew
                Layout.preferredHeight: visible ? Layout.preferredWidth * 9 / 32 : 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                radius: Theme.radiusSmall
                color: "transparent"
                clip: true

                OptImage {
                    id: previewImage
                    anchors.fill: parent
                    // Show the whole screenshot — letterbox if needed
                    fillMode: Image.PreserveAspectFit
                    source: {
                        const url = card.imageUrl || "";
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

    Item {
        id: countdownItem
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
    }

    // Countdown progress — a thin parallelogram strip flush with the card's
    // slanted left edge. Painted on a Canvas (not Shape) because the strip's
    // height shrinks every frame: Shape would re-tessellate the path on each
    // tick, while Canvas just refills. The Item is wide enough to contain
    // the slanted path so the bottom (which sticks out by |bg.skewPx|) isn't
    // clipped at the line's narrow visual width.
    Canvas {
        id: countdownLine
        readonly property real fraction: countdownItem.fraction
        readonly property real lineWidth: 3
        x: bg.x + bg.bl
        y: bg.y
        width: 2 * bg.absSkew + lineWidth
        height: bg.height
        visible: fraction > 0

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            // In canvas-local coords (origin at scene bg.x + bg.bl):
            //   bg's left edge at scene line-bottom → local x = 0
            //   bg's left edge at scene line-top    → local x = 2*bg.absSkew*f
            const topL = 2 * bg.absSkew * fraction;
            const topY = height * (1 - fraction);
            ctx.beginPath();
            ctx.moveTo(topL,             topY);
            ctx.lineTo(topL + lineWidth, topY);
            ctx.lineTo(lineWidth,        height);
            ctx.lineTo(0,                height);
            ctx.closePath();
            ctx.fillStyle = Theme.urgencyColor(card.urgency);
            ctx.fill();
        }

        onFractionChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
}
