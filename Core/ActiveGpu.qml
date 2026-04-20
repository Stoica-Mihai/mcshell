pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Detects which GPU has at least one display output currently connected.
// On hybrid setups (AMD iGPU + NVIDIA dGPU, Intel + dGPU, etc.) the monitor
// is cabled to one specific card's physical outputs; that's the GPU we want
// to surface for "GPU load" bar metrics even when the other card is idle.
//
// activeVendor is "NVIDIA" | "AMD" | "Intel" | "" (empty until probe lands
// or when nothing matches). Consumers treat "" as "don't know — pick on
// your own terms".
Singleton {
    id: root

    property string activeVendor: ""

    // PCI vendor IDs from /sys/class/drm/card*/device/vendor.
    readonly property var _vendorMap: ({
        "0x10de": "NVIDIA",
        "0x1002": "AMD",
        "0x8086": "Intel"
    })

    function detect() { _probe.running = true; }

    Component.onCompleted: detect()

    // Re-probe when screens change — someone plugging a cable in to the
    // other card should flip the active vendor.
    Connections {
        target: Quickshell
        function onScreensChanged() { root.detect(); }
    }

    Process {
        id: _probe
        command: ["sh", "-c",
            // Emit the PCI vendor id of every DRM card that has at least
            // one connected output, deduped.
            "for c in /sys/class/drm/card*-*/status; do " +
            "  [ \"$(cat \"$c\" 2>/dev/null)\" = connected ] || continue; " +
            "  card=$(basename $(dirname \"$c\") | cut -d- -f1); " +
            "  cat /sys/class/drm/$card/device/vendor 2>/dev/null; " +
            "done | sort -u"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(s => s.length > 0);
                // If exactly one vendor has a connected output, that's the
                // one. If multiple (e.g. laptop with internal panel on iGPU
                // + external on dGPU), prefer the first discrete match —
                // NVIDIA beats AMD beats Intel in that order, since a user
                // running multi-GPU with external discrete expects the
                // discrete one to be "primary".
                const priority = ["0x10de", "0x1002", "0x8086"];
                for (let i = 0; i < priority.length; i++) {
                    if (lines.indexOf(priority[i]) >= 0) {
                        root.activeVendor = root._vendorMap[priority[i]] || "";
                        return;
                    }
                }
                root.activeVendor = "";
            }
        }
    }
}
