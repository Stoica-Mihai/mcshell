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
    legendHint: "Enter copy"
    scanningState: !clipboardLoaded
    scanningIcon: Theme.iconClipboard
    scanningHint: "Loading..."

    // ── Data ──
    model: filteredClipEntries

    property bool clipboardLoaded: false
    property var allClipEntries: []
    property var filteredClipEntries: []
    property var _rawLines: []
    property int _loadedEnd: 0
    readonly property int _pageSize: 20

    // ── Lifecycle ──
    function onTabEnter() {
        if (!clipboardLoaded) loadClipboard();
        _loadedEnd = 0;
        _ensureLoaded(0);
    }

    function onTabLeave() {
        _loadedEnd = 0;
    }

    // ── Lazy loading — grow model as user navigates ──
    function _ensureLoaded(idx) {
        if (allClipEntries.length === 0) return;
        const needed = idx + _pageSize;
        if (needed <= _loadedEnd) return;
        _loadedEnd = Math.min(needed, allClipEntries.length);
        if (launcher.searchText === "")
            filteredClipEntries = allClipEntries.slice(0, _loadedEnd);
    }

    Connections {
        target: root.launcher
        function onSelectedIndexChanged() {
            if (root.launcher.activeCategory === root && root.launcher.searchText === "")
                root._ensureLoaded(root.launcher.selectedIndex);
        }
    }

    // ── Loading ──
    function loadClipboard() {
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
            root._loadedEnd = 0;
            root._ensureLoaded(0);
        }
        onFailed: {
            root.clipboardLoaded = true;
            root.filteredClipEntries = [];
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
        const query = (text || "").toLowerCase().trim();
        if (query === "") {
            _loadedEnd = 0;
            _ensureLoaded(launcher.selectedIndex);
            return;
        }
        // Search filters the full list — results are typically small
        const results = [];
        for (let i = 0; i < allClipEntries.length; i++) {
            if (allClipEntries[i].content.toLowerCase().indexOf(query) >= 0)
                results.push(allClipEntries[i]);
        }
        filteredClipEntries = results;
    }

    // ── Activate ──
    function onActivate(index) {
        if (index < 0 || index >= filteredClipEntries.length) return;
        copyClipEntry(filteredClipEntries[index]);
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            selectedIndex: root.launcher.selectedIndex
            sideCount: root.launcher.sideCount
            expandedWidth: root.launcher.expandedWidth
            stripWidth: root.launcher.stripWidth
            carouselHeight: root.launcher.carouselHeight
            borderColor: isCurrent && root.launcher.editMode ? Theme.accent : Theme.border
            onActivated: root.onActivate(index)
            onSelected: root.launcher.selectedIndex = index

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
                spacing: 10

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
                        // Extract size and dimensions from "[[ binary data 154 KiB png 1223x521 ]]"
                        const m = (modelData.content || "").match(/(\d+\s*\w+)\s+(png|jpe?g|webp|bmp)\s+(\d+x\d+)/i);
                        if (m) return m[3] + "  •  " + m[2].toUpperCase() + "  •  " + m[1];
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
