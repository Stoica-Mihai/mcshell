import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: parser

    // ── Public input ────────────────────────────────────
    property string filterText: ""
    onFilterTextChanged: applyFilter()

    // ── Public output ───────────────────────────────────
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

    property FileView configFile: FileView {
        path: ""

        onLoaded: parser.parseConfig(configFile.text())
        onLoadFailed: error => {
            console.warn("KeybindParser: failed to load niri config:", FileViewError.toString(error));
        }
    }

    function loadBindings() {
        if (configFile.path === "") {
            configFile.path = parser.configPath;
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
        const query = filterText.toLowerCase().trim();
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
}
