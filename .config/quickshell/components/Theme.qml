pragma Singleton
import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

// Same matugen glass as waybar and rofi. colors.css is rewritten with the wallpaper.
Singleton {
    id: root

    property color foreground: "#e0e2e8"
    property color glass: "#1d3953"
    property color glassDeep: "#0f1f2f"
    property color highlight: "#f4f5f6"
    property color gel: "#427db3"
    property color gelHi: "#b7c8d7"
    property color gelDeep: "#1e4971"
    property color gelActive: "#2589e4"
    property color rim: "#e6ebef"
    property color shadow: "#000000"

    readonly property string fontFamily: "Source Sans 3"
    readonly property int radius: 12
    readonly property int radiusSm: 8

    readonly property color ink: foreground
    readonly property color inkSoft: tint(foreground, 0.78)
    // Dark mode type is nearly white, and so is the gel disc behind category icons.
    readonly property bool lightType: foreground.r * 0.2126 + foreground.g * 0.7152 + foreground.b * 0.0722 > 0.62
    readonly property color iconInk: lightType ? Qt.darker(glassDeep, 1.55) : foreground
    readonly property color line: tint(rim, 0.55)
    readonly property color window: tint(glass, 0.38)
    readonly property color sidebar: tint(glassDeep, 0.46)
    readonly property color cardTop: sheen(0.22)
    readonly property color cardBottom: tint(glassDeep, 0.40)

    // Kept so older call sites still compile. Gel, not a separate mint palette.
    readonly property color glossTop: highlight
    readonly property color glossMid: gelHi
    readonly property color glossLow: gelActive
    readonly property color glossDeep: gelDeep
    readonly property color blueTop: highlight
    readonly property color blueMid: gel
    readonly property color blueLow: gelActive
    readonly property color blueDeep: glassDeep

    function tint(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    function sheen(alpha) {
        // Dark mode type is white, so the same highlight has to stay a veil.
        return tint(highlight, lightType ? alpha * 0.4 : alpha)
    }

    // Pale gel reads as a white cap over white type. Pull it toward the deep glass.
    function gloss(color) {
        if (!lightType)
            return color
        var deep = glassDeep
        var keep = 0.34
        return Qt.rgba(
            color.r * keep + deep.r * (1 - keep),
            color.g * keep + deep.g * (1 - keep),
            color.b * keep + deep.b * (1 - keep),
            color.a)
    }

    function readColors(text) {
        var names = {
            "foreground": "foreground",
            "glass": "glass",
            "glass_deep": "glassDeep",
            "highlight": "highlight",
            "gel": "gel",
            "gel_hi": "gelHi",
            "gel_deep": "gelDeep",
            "gel_active": "gelActive",
            "rim": "rim",
            "shadow": "shadow"
        }
        var re = /@define-color\s+([a-z_]+)\s+#([0-9a-fA-F]{6})/g
        var match
        while ((match = re.exec(text)) !== null) {
            var prop = names[match[1]]
            if (prop)
                root[prop] = "#" + match[2]
        }
    }

    FileView {
        path: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/waybar/colors.css"
        watchChanges: true
        onLoaded: root.readColors(text())
        onFileChanged: reload()
    }
}
