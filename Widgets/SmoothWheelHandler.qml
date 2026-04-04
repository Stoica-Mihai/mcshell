import QtQuick

// Reusable fast mouse/touchpad wheel scrolling for any Flickable or ListView.
WheelHandler {
    required property Flickable target

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        target.contentY = Math.max(0,
            Math.min(target.contentHeight - target.height,
                     target.contentY - event.angleDelta.y * 1.5));
    }
}
