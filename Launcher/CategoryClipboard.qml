import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Core

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Tab config ──
    tabLabel: "Clip"
    tabIcon: Theme.iconClipboard
    searchPlaceholder: "Search clipboard..."
    legendHint: Theme.hintEnter + " copy"
    scanningState: !clipboardLoaded || allClipEntries.length === 0
    scanningIcon: Theme.iconClipboard
    scanningHint: clipboardLoaded ? "No clipboard history" : "Loading..."

    // ── Data ──
    model: ScriptModel {
        id: clipModel
        values: root.launcher.searchText !== "" ? root.filteredClipEntries : root.allClipEntries
        objectProp: "id"
    }

    property bool clipboardLoaded: false
    property var allClipEntries: []
    property var filteredClipEntries: []
    property var _rawLines: []

    // ── Lifecycle ──
    function onTabEnter() {
        if (!clipboardLoaded) loadClipboard();
    }

    function onTabLeave() {}

    // ── Loading ──
    function loadClipboard() {
        clipboardLoaded = false;
        allClipEntries = [];
        _rawLines = [];
        clipHistProc.running = true;
    }

    SafeProcess {
        id: clipHistProc
        command: ["cliphist", "list"]
        failMessage: "cliphist not found — clipboard history unavailable"
        onRead: data => { root._rawLines.push(data); }
        onFinished: {
            root.allClipEntries = root.parseClipEntries(root._rawLines);
            root._rawLines = [];
            root.clipboardLoaded = true;
        }
        onFailed: {
            root.clipboardLoaded = true;
        }
    }

    function parseClipEntries(lines) {
        const imagePattern = /^\[\[\s*binary data\s+.+\s+(png|jpe?g|webp|bmp)\s+\d+x\d+\s*\]\]$/i;
        const entries = [];
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const tabIdx = line.indexOf("\t");
            if (tabIdx < 0) continue;
            const id = line.substring(0, tabIdx).trim();
            const content = line.substring(tabIdx + 1).trim();
            if (id === "" || content === "") continue;
            const isImage = imagePattern.test(content);
            entries.push({ id: id, content: content, raw: line, isImage: isImage });
        }
        return entries;
    }

    // ── Copy ──
    property string clipSelectRaw: ""
    SafeProcess {
        id: clipCopyProc
        command: ["bash", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "bash", root.clipSelectRaw]
        failMessage: "clipboard paste failed"
    }

    function copyClipEntry(entry) {
        clipSelectRaw = entry.raw;
        clipCopyProc.running = true;
        launcher.close();
    }

    // ── Search ──
    function onSearch(text) {
        filteredClipEntries = filterByQuery(text, allClipEntries,
            (item, q) => item.content.toLowerCase().indexOf(q) >= 0);
    }

    // ── Activate ──
    function onActivate(index) {
        const entries = launcher.searchText !== "" ? filteredClipEntries : allClipEntries;
        if (index >= 0 && index < entries.length) copyClipEntry(entries[index]);
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
                text: modelData.isImage ? Theme.iconImage : Theme.iconClipboard
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
                    text: modelData.isImage ? Theme.iconImage : Theme.iconClipboard
                    font.family: Theme.iconFont
                    font.pixelSize: 32
                    color: Theme.accent
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.isImage ? "Image" : (modelData.content || "")
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: modelData.isImage ? 18 : Theme.fontSizeSmall
                    font.bold: modelData.isImage ?? false
                    color: Theme.fg
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    elide: Text.ElideRight
                    maximumLineCount: modelData.isImage ? 1 : 12
                    horizontalAlignment: Text.AlignHCenter
                }

                // Show image metadata for image entries
                Text {
                    visible: modelData.isImage ?? false
                    Layout.fillWidth: true
                    text: {
                        const m = (modelData.content || "").match(/(\d+\s*\w+)\s+(png|jpe?g|webp|bmp)\s+(\d+x\d+)/i);
                        if (m) return m[3] + Theme.separator + m[2].toUpperCase() + Theme.separator + m[1];
                        return modelData.content || "";
                    }
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
