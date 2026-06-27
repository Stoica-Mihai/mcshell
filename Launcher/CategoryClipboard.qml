import QtQuick
import QtQuick.Layouts
import Quickshell
import Qs.DataControl
import qs.Config
import qs.Widgets

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
        onSearch(launcher.searchText || "");
    }

    // ── Lifecycle ──
    function onTabEnter() { _refreshClip(); }

    // ── Search ──
    function onSearch(text) {
        setItems(filterByQuery(text, ClipboardHistory.entries.values,
            (item, q) => item.content.toLowerCase().indexOf(q) >= 0));
    }

    // ── Activate ──
    function onActivate(index) {
        if (_validIndex(index)) {
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
            CollapsedCardIcon {
                visible: !parent.isCurrent && !(modelData.isImage ?? false)
                text: Theme.iconClipboard
            }

            // Clipboard previews are often screenshots at full screen
            // resolution — without sourceSize a 4K image decodes to ~32 MB
            // just to fill a ~100x480 strip card. OptImage's default of
            // decoding to widget size handles this. fillMode override stays
            // (we letterbox instead of crop so users see the whole image).
            OptImage {
                anchors.fill: parent
                anchors.margins: 4
                visible: !parent.isCurrent && (modelData.isImage ?? false)
                source: modelData.imageUrl ?? ""
                fillMode: Image.PreserveAspectFit
                // Pin sourceSize to the stable carousel height. OptImage's
                // default binds it to the card's width/height, which animate
                // on scroll/expand — re-decoding every frame and causing the
                // thumbnail to flicker / stay blank until the width settles.
                sourceSize.width: 0
                sourceSize.height: clipStrip.carouselHeight
            }

            // Expanded content
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                visible: parent.isCurrent
                spacing: Theme.spacingMedium

                Item { Layout.fillHeight: true; visible: !(modelData.isImage ?? false) }

                Text {
                    text: modelData.isImage ?? false ? Theme.iconImage : Theme.iconClipboard
                    font.family: Theme.iconFont
                    font.pixelSize: Theme.iconSizeLarge
                    color: Theme.accent
                    Layout.alignment: Qt.AlignHCenter
                }

                // Image preview (expanded) — OptImage caps decode at the
                // expanded card size (~700x480) instead of the source's
                // native resolution.
                OptImage {
                    visible: modelData.isImage ?? false
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // Only the current card holds the full decode; pin
                    // sourceSize so the expand animation doesn't re-decode.
                    source: clipStrip.isCurrent ? (modelData.imageUrl ?? "") : ""
                    sourceSize.width: 0
                    sourceSize.height: clipStrip.carouselHeight
                    fillMode: Image.PreserveAspectFit
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

                Item { Layout.fillHeight: true; visible: !(modelData.isImage ?? false) }

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
