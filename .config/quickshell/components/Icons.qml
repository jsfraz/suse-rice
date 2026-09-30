pragma Singleton
import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

// Crystal Remix lives at ~/.local/share/icons/crystal-remix-<color>/.
Singleton {
    id: root

    property string themeName: "crystal-remix-blue"

    readonly property string home: {
        var loc = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()
        if (loc.indexOf("file://") === 0)
            loc = loc.slice(7)
        return loc
    }
    readonly property string prefix: "file://" + home + "/.local/share/icons/" + themeName

    function readThemeFile() {
        var name = themeFile.text().trim()
        if (name.length > 0)
            themeName = name
    }

    Component.onCompleted: {
        if (!themeFile.loaded)
            rcmProc.run(["rcm", "get", "color", "-f", "blue"])
    }

    FileView {
        id: themeFile
        path: root.home + "/.cache/suse-rice/icon-theme"
        watchChanges: true
        onLoaded: root.readThemeFile()
        onFileChanged: reload()
    }

    Proc {
        id: rcmProc
        onFinished: (code, stdout, stderr) => {
            if (themeFile.loaded)
                return
            if (code !== 0)
                return
            root.themeName = "crystal-remix-" + (stdout.trim() || "blue")
        }
    }
}
