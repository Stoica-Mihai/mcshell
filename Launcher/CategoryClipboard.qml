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
    tabLabel: "Clip"
    tabIcon: Theme.iconClipboard
    searchPlaceholder: "Search clipboard..."
    legendHint: Theme.hintEnter + " copy"
    scanningState: ClipboardHistory.entries.values.length === 0
    scanningIcon: Theme.iconClipboard
    scanningHint: ClipboardHistory.available ? "No clipboard history" : "Clipboard unavailable"

    // ── Data ──
    model: ScriptModel {
        id: clipModel
        values: root.launcher.searchText !== "" ? root.filteredClipEntries : ClipboardHistory.entries.values
        objectProp: "timestamp"
    }

    property var filteredClipEntries: []

    // ── Search ──
    function onSearch(text) {
        filteredClipEntries = filterByQuery(text, ClipboardHistory.entries.values,
            (item, q) => item.content.toLowerCase().indexOf(q) >= 0);
    }

    // ── Activate ──
    function onActivate(index) {
        const entries = launcher.searchText !== "" ? filteredClipEntries : ClipboardHistory.entries.values;
        if (index >= 0 && index < entries.length) {
            ClipboardHistory.select(entries[index]);
            launcher.close();
        }
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            id: clipStrip
            launcher: root.launcher

            // Collapsed icon
            Text {
                anchors.centerIn: parent
                visible: !parent.isCurrent
                text: modelData.isImage ?? false ? Theme.iconImage : Theme.iconClipboard
                font.family: Theme.iconFont
                font.pixelSize: 24
                color: Theme.fgDim
            }

            // Expanded content
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: parent.isCurrent
                spacing: Theme.spacingMedium

                Text {
                    text: modelData.isImage ?? false ? Theme.iconImage : Theme.iconClipboard
                    font.family: Theme.iconFont
                    font.pixelSize: 32
                    color: Theme.accent
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.isImage ?? false ? "Image" : (modelData.content || "")
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: modelData.isImage ?? false ? 18 : Theme.fontSizeSmall
                    font.bold: modelData.isImage ?? false
                    color: Theme.fg
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    elide: Text.ElideRight
                    maximumLineCount: modelData.isImage ?? false ? 1 : 12
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
