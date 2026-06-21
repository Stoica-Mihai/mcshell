import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Core
import qs.Widgets

// Media bar widget — view over the shared Core/MediaService singleton, so
// player selection/pinning is shared across monitors rather than per bar.
Item {
    id: root

    readonly property bool hasMedia: MediaService.player !== null && MediaService.title !== ""
    implicitWidth: hasMedia ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight
    visible: hasMedia

    // Expose popup state for StatusBar click-catcher integration
    property bool popupVisible: false

    signal togglePopup()
    signal dismissPopup()

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall

        MediaControls {
            player: MediaService.player
            skipSize: Theme.iconSize - 2
        }

        // Track info: "Artist - Title" — scrolls on hover if truncated
        InfiniteText {
            id: trackLabel
            Layout.fillWidth: true
            Layout.maximumWidth: 200
            font.pixelSize: Theme.fontSizeSmall
            text: MediaService.artist ? `${MediaService.artist} - ${MediaService.title}` : MediaService.title
            onClicked: root.togglePopup()
        }
    }
}
