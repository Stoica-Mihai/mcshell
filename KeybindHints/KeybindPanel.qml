import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Config

PanelWindow {
    id: panel

    // ── Public API ──────────────────────────────────────
    property bool isOpen: false

    function open() {
        isOpen = true;
        visible = true;
        searchField.text = "";
        searchField.forceActiveFocus();
        if (allBindings.length === 0) loadBindings();
    }

    function close() {
        isOpen = false;
        visible = false;
        searchField.text = "";
    }

    function toggle() {
        if (isOpen) close(); else open();
    }

    // ── Window setup ────────────────────────────────────
    visible: false
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "mcshell-keybinds"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ── State ───────────────────────────────────────────
    property var allBindings: []
    property var filteredGroups: []

    // Category definitions: keyword patterns mapped to display names and Nerd Font icons
    readonly property var categories: [
        { name: "Apps",        icon: "\uf120", patterns: ["spawn"] },
        { name: "Workspaces",  icon: "\uf24d", patterns: ["workspace"] },
        { name: "Windows",     icon: "\uf2d0", patterns: ["window", "close-window", "fullscreen-window", "maximize-window"] },
        { name: "Columns",     icon: "\uf0db", patterns: ["column", "consume", "expel"] },
        { name: "Layout",      icon: "\uf58d", patterns: ["preset-column-width", "preset-window-height", "reset-window-height", "expand", "shrink", "switch-layout"] },
        { name: "Monitors",    icon: "\uf108", patterns: ["monitor"] },
        { name: "Screenshot",  icon: "\uf030", patterns: ["screenshot"] },
        { name: "Power",       icon: "\uf011", patterns: ["quit", "power-off", "suspend", "lock"] },
        { name: "Other",       icon: "\uf141", patterns: [] }
    ]

    // ── Config file reading via FileView ────────────────
    readonly property string configPath: Quickshell.env("HOME") + "/.config/niri/config.kdl"

    FileView {
        id: configFile
        path: ""

        onLoaded: panel.parseConfig(configFile.text())
        onLoadFailed: error => {
            console.warn("KeybindPanel: failed to load niri config:", FileViewError.toString(error));
        }
    }

    function loadBindings() {
        if (configFile.path === "") {
            configFile.path = panel.configPath;
        } else {
            configFile.reload();
        }
    }

    // ── KDL parser for niri binds block ─────────────────
    function parseConfig(text) {
        const bindings = [];
        const lines = text.split("\n");
        let inBinds = false;
        let braceDepth = 0;
        let currentKey = "";
        let actionLines = [];

        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i];
            // Strip inline comments (not inside quotes)
            const trimmed = stripComment(raw).trim();

            if (trimmed === "" || trimmed.startsWith("//")) continue;

            // Detect top-level binds block
            if (!inBinds) {
                if (/^binds\s*\{/.test(trimmed)) {
                    inBinds = true;
                    braceDepth = 1;
                }
                continue;
            }

            // Count braces on this line
            const opens = countChar(trimmed, '{');
            const closes = countChar(trimmed, '}');

            if (braceDepth === 1) {
                // Single-line bind:  Mod+Key { action "arg"; }
                const oneLiner = trimmed.match(/^([A-Za-z0-9_+\-]+)\s+\{(.+)\}$/);
                if (oneLiner) {
                    const key = oneLiner[1];
                    const body = oneLiner[2].trim().replace(/;\s*$/, "").trim();
                    if (body) {
                        bindings.push({
                            key: formatKeyCombo(key),
                            action: humanizeAction(body),
                            rawAction: body
                        });
                    }
                    // braceDepth unchanged (opened and closed on same line)
                    continue;
                }

                // Multi-line bind start:  Mod+Key {
                const multiStart = trimmed.match(/^([A-Za-z0-9_+\-]+)\s+\{$/);
                if (multiStart) {
                    currentKey = multiStart[1];
                    actionLines = [];
                    braceDepth += 1; // now at depth 2
                    continue;
                }

                // Closing brace of the binds block itself
                if (trimmed === "}") {
                    braceDepth -= 1;
                    if (braceDepth === 0) inBinds = false;
                    continue;
                }

                // Update depth for other lines
                braceDepth += opens - closes;

            } else if (braceDepth >= 2) {
                // Inside a multi-line keybind block
                braceDepth += opens - closes;

                if (braceDepth >= 2 && trimmed !== "}") {
                    const cleaned = trimmed.replace(/;\s*$/, "").trim();
                    if (cleaned) actionLines.push(cleaned);
                }

                // Returned to depth 1 means we closed this keybind
                if (braceDepth === 1 && currentKey) {
                    const body = actionLines.join("; ");
                    if (body) {
                        bindings.push({
                            key: formatKeyCombo(currentKey),
                            action: humanizeAction(body),
                            rawAction: body
                        });
                    }
                    currentKey = "";
                    actionLines = [];
                }

                if (braceDepth <= 0) {
                    inBinds = false;
                    braceDepth = 0;
                }
            }
        }

        allBindings = bindings;
        applyFilter();
    }

    function stripComment(line) {
        // Remove // comments that are not inside quotes
        let inQuote = false;
        for (let i = 0; i < line.length; i++) {
            if (line[i] === '"' && (i === 0 || line[i - 1] !== '\\')) {
                inQuote = !inQuote;
            }
            if (!inQuote && line[i] === '/' && i + 1 < line.length && line[i + 1] === '/') {
                return line.substring(0, i);
            }
        }
        return line;
    }

    function countChar(s, ch) {
        let n = 0;
        let inQuote = false;
        for (let i = 0; i < s.length; i++) {
            if (s[i] === '"' && (i === 0 || s[i - 1] !== '\\')) inQuote = !inQuote;
            if (!inQuote && s[i] === ch) n++;
        }
        return n;
    }

    function formatKeyCombo(raw) {
        let s = raw;
        s = s.replace(/Mod\+/g, "Super + ");
        s = s.replace(/Shift\+/g, "Shift + ");
        s = s.replace(/Ctrl\+/g, "Ctrl + ");
        s = s.replace(/Alt\+/g, "Alt + ");
        s = s.replace(/WheelScrollDown/g, "Scroll Down");
        s = s.replace(/WheelScrollUp/g, "Scroll Up");
        s = s.replace(/WheelScrollLeft/g, "Scroll Left");
        s = s.replace(/WheelScrollRight/g, "Scroll Right");
        return s.trim();
    }

    function humanizeAction(raw) {
        let s = raw.trim();

        // spawn "command" args... -> Run: command args
        const spawnMatch = s.match(/^spawn\s+"([^"]+)"(.*)$/);
        if (spawnMatch) {
            const cmd = spawnMatch[1].split("/").pop(); // basename
            const args = spawnMatch[2].trim().replace(/"/g, "");
            return "Run: " + cmd + (args ? " " + args : "");
        }
        const spawnSimple = s.match(/^spawn\s+(\S+)(.*)$/);
        if (spawnSimple) {
            const cmd = spawnSimple[1].replace(/"/g, "").split("/").pop();
            const args = spawnSimple[2].trim().replace(/"/g, "");
            return "Run: " + cmd + (args ? " " + args : "");
        }

        // Replace hyphens with spaces and capitalize
        s = s.replace(/-/g, " ");
        if (s.length > 0) {
            s = s.charAt(0).toUpperCase() + s.slice(1);
        }
        return s;
    }

    function categorizeBinding(binding) {
        const raw = (binding.rawAction || "").toLowerCase();
        for (let i = 0; i < categories.length - 1; i++) {
            const cat = categories[i];
            for (let j = 0; j < cat.patterns.length; j++) {
                if (raw.indexOf(cat.patterns[j]) >= 0) return cat.name;
            }
        }
        return "Other";
    }

    function applyFilter() {
        const query = searchField.text.toLowerCase().trim();
        const grouped = {};

        for (let i = 0; i < allBindings.length; i++) {
            const b = allBindings[i];

            if (query !== "") {
                const keyHit = b.key.toLowerCase().indexOf(query) >= 0;
                const actHit = b.action.toLowerCase().indexOf(query) >= 0;
                if (!keyHit && !actHit) continue;
            }

            const cat = categorizeBinding(b);
            if (!grouped[cat]) grouped[cat] = [];
            grouped[cat].push(b);
        }

        // Build flat list with section headers, preserving category order
        const result = [];
        for (let c = 0; c < categories.length; c++) {
            const catName = categories[c].name;
            const items = grouped[catName];
            if (!items || items.length === 0) continue;
            result.push({
                isHeader: true,
                name: catName,
                icon: categories[c].icon,
                count: items.length
            });
            for (let j = 0; j < items.length; j++) {
                result.push({
                    isHeader: false,
                    key: items[j].key,
                    action: items[j].action
                });
            }
        }

        filteredGroups = result;
    }

    // ── UI ──────────────────────────────────────────────

    // Semi-transparent dimmer -- click to close
    Rectangle {
        anchors.fill: parent
        color: Theme.backdrop

        MouseArea {
            anchors.fill: parent
            onClicked: panel.close()
        }
    }

    // Centered card
    Rectangle {
        id: card
        width: Math.min(700, parent.width * 0.85)
        height: parent.height * 0.82
        anchors.centerIn: parent
        radius: 12
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        clip: true

        ColumnLayout {
            id: cardColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Header row ──────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: Theme.iconKeyboard
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Keybindings"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.fg
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "ESC to close"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fgDim
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // ── Search field ────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 8
                color: Theme.bgSolid
                border.width: 1
                border.color: searchField.activeFocus ? Theme.accent : Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Image {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        sourceSize.width: 16
                        sourceSize.height: 16
                        source: "image://icon/edit-find"
                        opacity: 0.5
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                        clip: true
                        selectByMouse: true

                        onTextChanged: panel.applyFilter()

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                panel.close();
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Filter keybindings..."
                            color: Theme.fgDim
                            font: parent.font
                            visible: !parent.text
                        }
                    }
                }
            }

            // ── Scrollable keybind list ─────────────────
            ListView {
                id: bindList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: panel.filteredGroups
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3000
                maximumFlickVelocity: 4000

                // Fast mouse wheel scrolling
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        bindList.contentY = Math.max(
                            0,
                            Math.min(bindList.contentHeight - bindList.height,
                                     bindList.contentY - event.angleDelta.y * 1.5)
                        );
                    }
                }
                spacing: 0

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 6

                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: Theme.fgDim
                        opacity: 0.4
                    }
                }

                delegate: Loader {
                    id: delegateLoader
                    required property var modelData
                    required property int index
                    width: bindList.width

                    sourceComponent: modelData.isHeader ? sectionHeader : bindingRow

                    Component {
                        id: sectionHeader

                        Item {
                            width: delegateLoader.width
                            height: 40

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                anchors.bottomMargin: 4
                                spacing: 8

                                Text {
                                    text: delegateLoader.modelData.icon || ""
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                    color: Theme.accent
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: delegateLoader.modelData.name || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    color: Theme.accent
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    height: 1
                                    color: Theme.border
                                }

                                Text {
                                    text: delegateLoader.modelData.count + ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.fgDim
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 4
                                }
                            }
                        }
                    }

                    Component {
                        id: bindingRow

                        Rectangle {
                            width: delegateLoader.width
                            height: 34
                            radius: 6
                            color: rowHover.hovered ? Theme.bgHover : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Theme.animFast }
                            }

                            HoverHandler {
                                id: rowHover
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 12

                                // Key caps
                                Row {
                                    Layout.preferredWidth: Math.min(280, delegateLoader.width * 0.42)
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4
                                    layoutDirection: Qt.LeftToRight

                                    Repeater {
                                        model: (delegateLoader.modelData.key || "").split(" + ")

                                        Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: capText.implicitWidth + 14
                                            height: 22
                                            radius: 4
                                            color: Qt.rgba(
                                                Theme.accent.r,
                                                Theme.accent.g,
                                                Theme.accent.b,
                                                0.12
                                            )
                                            border.width: 1
                                            border.color: Qt.rgba(
                                                Theme.accent.r,
                                                Theme.accent.g,
                                                Theme.accent.b,
                                                0.25
                                            )

                                            Text {
                                                id: capText
                                                anchors.centerIn: parent
                                                text: modelData.trim()
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.bold: true
                                                color: Theme.accent
                                            }
                                        }
                                    }
                                }

                                // Arrow separator
                                Text {
                                    text: Theme.iconArrowTo
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.fgDim
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Action description
                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: delegateLoader.modelData.action || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            // ── Footer ──────────────────────────────────
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: {
                    const total = panel.allBindings.length;
                    if (total === 0) return "Loading keybindings...";
                    let shown = 0;
                    for (let i = 0; i < panel.filteredGroups.length; i++) {
                        if (!panel.filteredGroups[i].isHeader) shown++;
                    }
                    if (searchField.text && shown === 0) return "No matching keybindings";
                    if (searchField.text) return shown + " of " + total + " keybindings";
                    return total + " keybinding" + (total !== 1 ? "s" : "") + " from niri config";
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.fgDim
            }
        }
    }
}
