import QtQuick

// Shared click-dispatch MouseArea for bar widgets that react to more than
// one mouse button. Three bar widgets (Clock, Weather, SysWaveform) used
// to repeat the same L/R/(M) + onCanceled fallback boilerplate with
// signals whose names differed by one word each — that's the kind of
// across-file behavioural duplication the Rule of Three is designed to
// catch.
//
// Consumers instantiate this in place of a raw MouseArea and connect only
// the signals they care about. Unused buttons become no-ops.
//
// `handleCanceled` defaults to true because Wayland layer-shell surfaces
// can cancel the first pointer grab after startup — the fallback makes
// that first click still reach the primary handler instead of being
// dropped. Opt out only if your widget has a reason to treat a canceled
// press as "nothing happened".
MouseArea {
    id: root

    signal leftClicked()
    signal rightClicked()
    signal middleClicked()

    property bool handleCanceled: true

    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: event => {
        if (event.button === Qt.RightButton)       root.rightClicked();
        else if (event.button === Qt.MiddleButton) root.middleClicked();
        else                                       root.leftClicked();
    }

    onCanceled: if (root.handleCanceled) root.leftClicked()
}
