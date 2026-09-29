import QtQuick
import Quickshell.Io

// One-shot command. finished() runs after stdout and stderr have been collected.
// Item, not QtObject: Process has to live in a default property.
Item {
    id: root
    signal finished(int code, string stdout, string stderr)

    function run(argv) {
        process.exec(argv)
    }

    Process {
        id: process
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }
        onExited: (code, status) => Qt.callLater(() => root.finished(code, out.text, err.text))
    }
}
