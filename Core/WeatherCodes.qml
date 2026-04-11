pragma Singleton

import QtQuick
import Quickshell
import qs.Config

// WMO weather code → icon, color, and human-readable name.
// Single source of truth shared between the bar Weather widget and the popup.
Singleton {
    id: root

    function icon(code) {
        if (code === 0) return Theme.iconSun;
        if (code >= 1 && code <= 3) return Theme.iconCloudSun;
        if (code === 45 || code === 48) return Theme.iconSmog;
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return Theme.iconCloudRain;
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return Theme.iconSnowflake;
        if (code >= 95) return Theme.iconBolt;
        return Theme.iconCloud;
    }

    function color(code) {
        if (code === 0 || (code >= 1 && code <= 3)) return Theme.yellow;
        if (code === 45 || code === 48) return Theme.fgDim;
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return Theme.cyan;
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return Theme.fg;
        if (code >= 95) return Theme.red;
        return Theme.fgDim;
    }

    function name(code) {
        if (code === 0) return "Clear";
        if (code === 1) return "Mainly clear";
        if (code === 2) return "Partly cloudy";
        if (code === 3) return "Overcast";
        if (code === 45 || code === 48) return "Fog";
        if (code >= 51 && code <= 57) return "Drizzle";
        if (code >= 61 && code <= 67) return "Rain";
        if (code >= 71 && code <= 77) return "Snow";
        if (code >= 80 && code <= 82) return "Rain showers";
        if (code === 85 || code === 86) return "Snow showers";
        if (code >= 95 && code <= 99) return "Thunderstorm";
        return "Unknown";
    }
}
