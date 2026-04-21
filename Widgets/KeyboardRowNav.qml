import QtQuick
import qs.Config

// Keyboard-driven row navigation for settings popups with a declarative
// row-descriptor model. Consumers pass an array of rows, then forward
// the relevant Keys.on* handlers to navigate / adjust / activate.
//
// Previously duplicated between `ClockSettingsPopup` and
// `SysInfoSettingsPopup` — the keyboard handlers and a kind-driven
// dispatch function almost verbatim in both, diverging only on which
// row kinds they supported. This object unifies the common kinds and
// provides an `onAdjust`/`onActivate` escape hatch for anything custom
// (e.g. the per-GPU rows in the sysinfo popup).
//
// Row shape (fields are all optional unless a given kind requires them):
//   { kind: "cycle",  setting: "foo", values: [a,b,c], model: ["A","B","C"] }
//   { kind: "toggle", setting: "foo" }       // flips a boolean setting
//   { kind: "check",  setting: "foo" }       // same behaviour as toggle
//   { kind: "custom", onActivate(), onAdjust(dir) }  // fully user-driven
//
// For any kind, providing an explicit `onAdjust` / `onActivate` overrides
// the default behaviour — useful when a row's "activate" doesn't map to
// flipping a single UserSettings boolean.
//
// Usage:
//   KeyboardRowNav { id: nav; rows: root._rows }
//   Keys.onUpPressed:     nav.navigate(-1)
//   Keys.onDownPressed:   nav.navigate(1)
//   Keys.onLeftPressed:   nav.adjust(-1)
//   Keys.onRightPressed:  nav.adjust(1)
//   Keys.onReturnPressed: nav.activate()
//   Keys.onSpacePressed:  nav.activate()
QtObject {
    id: root

    property var rows: []
    readonly property int rowCount: rows.length
    property int selectedRow: 0

    function navigate(dir) {
        if (rowCount === 0) return;
        selectedRow = (selectedRow + dir + rowCount) % rowCount;
    }

    function reset() { selectedRow = 0; }

    function adjust(dir) {
        const r = rows[selectedRow];
        if (!r) return;
        if (r.onAdjust) { r.onAdjust(dir); return; }
        if (r.kind === "cycle" && r.values && r.setting) {
            const cur = Math.max(0, r.values.indexOf(UserSettings[r.setting]));
            UserSettings[r.setting] = r.values[(cur + dir + r.values.length) % r.values.length];
        }
    }

    function activate() {
        const r = rows[selectedRow];
        if (!r) return;
        if (r.onActivate) { r.onActivate(); return; }
        if ((r.kind === "toggle" || r.kind === "check") && r.setting) {
            UserSettings[r.setting] = !UserSettings[r.setting];
        }
    }
}
