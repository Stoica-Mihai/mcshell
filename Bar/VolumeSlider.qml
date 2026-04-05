import QtQuick
import qs.Config
import qs.Widgets

Item {
    id: root

    required property var volumeSource

    implicitWidth: parent ? parent.width : 240
    implicitHeight: slider.implicitHeight

    ControlSlider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        label: "Volume"
        value: root.volumeSource.rawVolume
        muted: root.volumeSource.muted
        icon: Theme.volumeIcon(root.volumeSource.rawVolume, root.volumeSource.muted)
        onMoved: newValue => {
            root.volumeSource.setVolume(newValue);
        }
        onIconClicked: {
            root.volumeSource.toggleMute();
        }
    }
}
