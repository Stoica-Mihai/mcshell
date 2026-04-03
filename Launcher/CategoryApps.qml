import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Widgets

LauncherCategory {
    id: root

    // ── Launcher reference ──
    required property var launcher

    // ── Tab config ──
    tabLabel: "Apps"
    tabIcon: Theme.iconApps
    searchPlaceholder: "Search apps..."
    legendHint: Theme.hintEnter + " launch"
    scanningState: allApps.length === 0
    scanningIcon: Theme.iconApps
    scanningHint: "No applications found"

    // ── Data ──
    model: filteredApps

    readonly property var allApps: {
        if (typeof DesktopEntries === "undefined") return [];
        const raw = DesktopEntries.applications.values;
        const apps = [];
        for (let i = 0; i < raw.length; i++) {
            const e = raw[i];
            if (!e || e.noDisplay) continue;
            apps.push(e);
        }
        apps.sort((a, b) => (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase()));
        return apps;
    }
    property var filteredApps: []
    onAllAppsChanged: applyAppFilter(launcher.searchText)

    // ── Search ──
    function onSearch(text) { applyAppFilter(text); }

    function applyAppFilter(text) {
        const query = (text || "").toLowerCase().trim();
        if (query === "") { filteredApps = allApps; return; }
        const scored = [];
        for (let i = 0; i < allApps.length; i++) {
            const app = allApps[i];
            let score = fuzzyScore(query, (app.name || "").toLowerCase());
            if (score < 0) {
                const alt = fuzzyScore(query, (app.comment || app.genericName || "").toLowerCase());
                if (alt >= 0) score = alt - 10;
            }
            if (score >= 0) scored.push({ app: app, score: score });
        }
        scored.sort((a, b) => b.score - a.score);
        filteredApps = scored.map(s => s.app);
    }

    function fuzzyScore(query, target) {
        if (target.indexOf(query) >= 0) {
            if (target.indexOf(query) === 0) return 200;
            return 150;
        }
        var qi = 0, lastMatchIdx = -1, score = 100;
        for (var ti = 0; ti < target.length && qi < query.length; ti++) {
            if (target[ti] === query[qi]) {
                if (lastMatchIdx >= 0 && ti === lastMatchIdx + 1) score += 5;
                if (ti === 0 || target[ti - 1] === " " || target[ti - 1] === "-") score += 3;
                lastMatchIdx = ti;
                qi++;
            }
        }
        if (qi < query.length) return -1;
        score -= (lastMatchIdx - (lastMatchIdx - qi + 1));
        return score;
    }

    // ── Activate ──
    function onActivate(index) {
        if (index < 0 || index >= filteredApps.length) return;
        launchApp(filteredApps[index]);
    }

    function launchApp(entry) {
        launcher.close();
        Qt.callLater(function() { if (entry) entry.execute(); });
    }

    // ── Card delegate ──
    cardDelegate: Component {
        CarouselStrip {
            launcher: root.launcher
            onActivated: root.onActivate(index)
            onSelected: root.launcher.selectedIndex = index

            // Collapsed
            OptImage {
                anchors.centerIn: parent
                visible: !parent.isCurrent
                width: 40; height: 40
                sourceSize.width: 40; sourceSize.height: 40
                source: "image://icon/" + (modelData.icon || "application-x-executable")
            }

            // Expanded
            ColumnLayout {
                anchors.centerIn: parent
                visible: parent.isCurrent
                spacing: Theme.spacingLarge
                width: parent.width - 40

                OptImage {
                    Layout.alignment: Qt.AlignHCenter
                    width: 80; height: 80
                    sourceSize.width: 80; sourceSize.height: 80
                    source: "image://icon/" + (modelData.icon || "application-x-executable")
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.name || ""
                    font.family: Theme.fontFamily
                    font.pixelSize: 18; font.bold: true
                    color: Theme.fg
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.comment || modelData.genericName || ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.fgDim
                    elide: Text.ElideRight
                    visible: text !== ""
                    Layout.maximumWidth: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                }
            }
        }
    }
}
