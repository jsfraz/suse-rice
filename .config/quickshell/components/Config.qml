pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Directory of this config (shell.qml), whether it is symlinked or passed to qs -p.
    readonly property string dir: {
        var url = Qt.resolvedUrl("..").toString()
        if (url.startsWith("file://"))
            url = url.slice(7)
        if (url.endsWith("/"))
            url = url.slice(0, -1)
        return decodeURIComponent(url)
    }
    readonly property string scripts: dir + "/scripts"
}
