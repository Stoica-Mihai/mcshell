import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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

    // ── Card background — skewed parallelogram ──────────
    ParallelogramCard {
        id: bg
        x: card.slideX
        width: parent.width
        height: content.implicitHeight + Theme.popupPadding * 2
        // Fully opaque even when blur is on. Blur regions are necessarily
        // axis-aligned rectangles (a polygon Region stair-steps its edges
        // via QRegion scanline rasterization), so a translucent fill leaks
        // the rectangular blur boundary through the slanted parallelogram
        // and makes the slanted countdown line look non-parallel to the
        // visible (rectangular) card edge. Opaque fill makes the slanted
        // bg edge the visible edge, restoring parallel-ness.
        backgroundColor: Theme.bg
        showBorder: false
        _skew: -0.10

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

            // Large image preview (e.g. screenshot) — smaller and centered
            // so the parallelogram's bottom-right slant doesn't clip into it.
            Rectangle {
                id: previewContainer
                visible: previewImage.status === Image.Ready
                Layout.preferredWidth: parent.width - 2 * bg._absSkew
                Layout.preferredHeight: visible ? Layout.preferredWidth * 9 / 32 : 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                radius: Theme.radiusSmall
                color: Theme.bgSolid
                clip: true

                OptImage {
                    id: previewImage
                    anchors.fill: parent
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

    // ── Countdown state holder (no visuals) ──────────────
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

    // ── Countdown progress — a Shape painting a parallelogram strip flush
    // with the card's slanted left edge. The ENCLOSING Item is wide enough
    // (2*bg._absSkew + lineWidth) to fully contain the slanted path so Qt's
    // Shape doesn't clip its bottom — using a 3px-wide wrapper (the line's
    // visual width) clips the bottom of tall cards because the bottom-left
    // vertex sits ~|bg._skewPx| pixels outside the wrapper.
    Item {
        id: countdownLine
        readonly property real fraction: countdownItem.fraction
        readonly property real lineWidth: 3
        x: bg.x + bg._bl
        y: bg.y
        width: 2 * bg._absSkew + lineWidth
        height: bg.height
        visible: fraction > 0

        // In Item-local coords (Item origin at scene bg.x + bg._bl):
        //   bg's left edge at scene line-bottom → local x = 0
        //   bg's left edge at scene line-top    → local x = 2*bg._absSkew*f
        readonly property real _topL: 2 * bg._absSkew * fraction
        readonly property real _topY: height * (1 - fraction)
        readonly property real _botY: height

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.urgencyColor(card.urgency)
                strokeColor: "transparent"
                strokeWidth: 0
                startX: countdownLine._topL;                          startY: countdownLine._topY
                PathLine { x: countdownLine._topL + countdownLine.lineWidth; y: countdownLine._topY }
                PathLine { x: countdownLine.lineWidth;                       y: countdownLine._botY }
                PathLine { x: 0;                                             y: countdownLine._botY }
                PathLine { x: countdownLine._topL;                           y: countdownLine._topY }
            }
        }
    }
}
