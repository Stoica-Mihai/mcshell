import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland._DataControl
import qs.Config

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Tab config ──
    tabName: "clipboard"
    tabLabel: "Clip"
    tabIcon: Theme.iconClipboard
    searchPlaceholder: "Search clipboard..."
    legendHint: Theme.hintEnter + " copy"
    scanningState: ClipboardHistory.entries.values.length === 0
    scanningIcon: Theme.iconClipboard
    scanningHint: ClipboardHistory.available ? "No clipboard history" : "Clipboard unavailable"

    // ── Data ──
    Connections {
        target: ClipboardHistory.entries
        function onValuesChanged() { root._refreshClip(); }
    }

    function _refreshClip() {
        if (launcher.searchText !== "")
            onSearch(launcher.searchText);
        else
            setItems(ClipboardHistory.entries.values);
    }

    // ── Lifecycle ──
    function onTabEnter() { _refreshClip(); }

    // ── Search ──
    function onSearch(text) {
        if (text === "") { setItems(ClipboardHistory.entries.values); return; }
        setItems(filterByQuery(text, ClipboardHistory.entries.values,
            (item, q) => item.content.toLowerCase().indexOf(q) >= 0));
    }

    // ── Activate ──
    function onActivate(index) {
        if (index >= 0 && index < _sourceData.length) {
            ClipboardHistory.select(_sourceData[index]);
            launcher.close();
        }
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            id: clipStrip
            launcher: root.launcher

            // Collapsed: icon or thumbnail
            Text {
                anchors.centerIn: parent
                visible: !parent.isCurrent && !(modelData.isImage ?? false)
                text: Theme.iconClipboard
                font.family: Theme.iconFont
                font.pixelSize: 24
                color: Theme.fgDim
            }

            Image {
                anchors.fill: parent
                anchors.margins: 4
                visible: !parent.isCurrent && (modelData.isImage ?? false)
                source: modelData.imageUrl ?? ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            // Expanded content
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                visible: parent.isCurrent
                spacing: Theme.spacingMedium

                Text {
                    text: modelData.isImage ?? false ? Theme.iconImage : Theme.iconClipboard
                    font.family: Theme.iconFont
                    font.pixelSize: 32
                    color: Theme.accent
                    Layout.alignment: Qt.AlignHCenter
                }

                // Image preview (expanded)
                Image {
                    visible: modelData.isImage ?? false
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    source: modelData.imageUrl ?? ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    }

                // Text content (non-image)
                Text {
                    visible: !(modelData.isImage ?? false)
                    Layout.fillWidth: true
                    text: modelData.content || ""
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fg
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    elide: Text.ElideRight
                    maximumLineCount: 12
                    horizontalAlignment: Text.AlignHCenter
                }

                // Image metadata
                Text {
                    visible: modelData.isImage ?? false
                    Layout.fillWidth: true
                    text: modelData.content || ""
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fgDim
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
