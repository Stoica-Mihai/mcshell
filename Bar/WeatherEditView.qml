import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Widgets

// Weather popup "edit" view: city search + geocoding results list.
// Selection state (geoResults, geoError, geoLoading, selectedIndex) lives
// on the parent popup so it survives view reloads; this view just renders.
ColumnLayout {
    id: root

    required property var popup

    Layout.fillWidth: true
    spacing: Theme.spacingSmall

    // Delay focus grab until the popup open animation + FocusScope setup settle.
    Timer {
        id: focusTimer
        interval: Theme.animSmooth + 50
        running: true
        onTriggered: if (searchBox.visible) searchBox.field.forceActiveFocus()
    }

    // Header — "Set location" / "Change location" (click outside to dismiss)
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 28

        Text {
            anchors.centerIn: parent
            text: UserSettings.weatherConfigured ? "Change location" : "Set your location"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            color: Theme.fg
        }
    }

    // Search input — parallelogram-skewed to match the bar aesthetic
    SkewTextField {
        id: searchBox
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacingLarge
        Layout.rightMargin: Theme.spacingLarge
        icon: Theme.iconSearch
        placeholder: "Start typing to search cities"

        field.onTextChanged: root.popup.queueGeocode(searchBox.text)
        field.Keys.onReturnPressed: {
            const results = root.popup.geoResults;
            const idx = root.popup.selectedIndex;
            if (results.length > 0 && idx >= 0 && idx < results.length)
                root.popup.selectLocation(results[idx]);
        }
        field.Keys.onDownPressed: {
            const n = root.popup.geoResults.length;
            if (n === 0) return;
            root.popup.selectedIndex = (root.popup.selectedIndex + 1) % n;
        }
        field.Keys.onUpPressed: {
            const n = root.popup.geoResults.length;
            if (n === 0) return;
            root.popup.selectedIndex = (root.popup.selectedIndex - 1 + n) % n;
        }
        field.Keys.onEscapePressed: {
            if (UserSettings.weatherConfigured) root.popup.cancelEdit();
        }
    }

    // Empty hint / error / results — collapses when idle so the popup
    // stays compact and the input has symmetric top/bottom padding.
    Item {
        readonly property bool _hasContent: root.popup.geoLoading
            || root.popup.geoError !== ""
            || root.popup.geoResults.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: _hasContent
            ? Math.max(60, Math.min(root.popup.geoResults.length * 40, 240))
            : 0

        Text {
            anchors.centerIn: parent
            visible: root.popup.geoLoading
            text: "Searching..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.fgDim
        }

        Text {
            anchors.centerIn: parent
            visible: !root.popup.geoLoading && root.popup.geoError !== ""
            text: root.popup.geoError
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.red
        }

        ListView {
            id: resultsList
            anchors.fill: parent
            visible: !root.popup.geoLoading && root.popup.geoResults.length > 0
            clip: true
            model: root.popup.geoResults
            spacing: 2
            interactive: contentHeight > height
            currentIndex: root.popup.selectedIndex
            highlightFollowsCurrentItem: true
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                id: resultRow
                required property var modelData
                required property int index

                readonly property bool _isSelected: root.popup.selectedIndex === index

                width: ListView.view.width
                height: 36
                radius: Theme.radiusSmall
                color: _isSelected ? Theme.accentLight
                     : mouse.containsMouse ? Theme.bgHover
                     : "transparent"
                border.width: _isSelected ? 1 : 0
                border.color: Theme.accent

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMedium
                    anchors.rightMargin: Theme.spacingMedium
                    spacing: Theme.spacingMedium

                    Text {
                        text: Theme.iconLocationPin
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: resultRow._isSelected ? Theme.accent : Theme.fgDim
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.displayName
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fg
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.popup.selectLocation(modelData)
                }
            }
        }
    }
}
