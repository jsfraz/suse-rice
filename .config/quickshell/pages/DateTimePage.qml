import QtQuick
import qs.components

Item {
    id: root
    property string timezone: ""
    property bool ntp: true
    property var zones: []
    property string manual: ""
    property bool busy: false
    property string message: ""
    property var now: new Date()

    function script() { return Config.scripts + "/timedate.py" }

    function pad(n) { return (n < 10 ? "0" : "") + n }

    function stamp(date) {
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
                + " " + pad(date.getHours()) + ":" + pad(date.getMinutes()) + ":" + pad(date.getSeconds())
    }

    function zoneLabels() {
        var out = zones.slice()
        if (timezone && out.indexOf(timezone) < 0)
            out.unshift(timezone)
        return out
    }

    function take(stdout, stderr) {
        busy = false
        var parsed = null
        try {
            parsed = JSON.parse(stdout)
        } catch (e) {
            message = (stderr || stdout || "Could not load the time").trim()
            return
        }
        if (!parsed.ok) {
            message = parsed.error || "Action failed"
            return
        }
        if (parsed.timezone !== undefined)
            timezone = parsed.timezone
        if (parsed.ntp !== undefined)
            ntp = parsed.ntp
        if (parsed.zones)
            zones = parsed.zones
        message = ""
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Component.onCompleted: {
        manual = stamp(new Date())
        statusProc.run(["python3", script(), "status"])
        zoneProc.run(["python3", script(), "zones"])
    }

    Proc {
        id: statusProc
        onFinished: (code, stdout, stderr) => root.take(stdout, stderr)
    }
    Proc {
        id: zoneProc
        onFinished: (code, stdout, stderr) => root.take(stdout, stderr)
    }
    Proc {
        id: writeProc
        onFinished: (code, stdout, stderr) => root.take(stdout, stderr)
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Date and time"

        AeroCard {
            width: parent.width
            Text {
                width: parent.width
                text: Qt.formatDateTime(root.now, "HH:mm:ss")
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 32
                font.weight: 650
            }
            BodyText { text: Qt.formatDateTime(root.now, "MMMM d, yyyy") + "   ·   " + root.timezone }
        }

        AeroCard {
            width: parent.width
            Row {
                width: parent.width
                spacing: 12
                BodyText {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Automatic time (NTP)"
                }
                AeroSwitch {
                    checked: root.ntp
                    enabled: !root.busy
                    onClicked: {
                        root.busy = true
                        writeProc.run(["python3", root.script(), "ntp", root.ntp ? "false" : "true"])
                    }
                }
            }
            BodyText {
                width: parent.width
                visible: !root.ntp
                text: "Manual time as YYYY-MM-DD HH:MM:SS"
            }
            AeroField {
                width: parent.width
                visible: !root.ntp
                text: root.manual
                onTextChanged: root.manual = text
            }
            AeroButton {
                visible: !root.ntp
                text: "Set time"
                enabled: !root.busy
                onClicked: {
                    root.busy = true
                    writeProc.run(["python3", root.script(), "time", root.manual])
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Time zone"; width: parent.width }
            AeroCombo {
                width: parent.width
                enabled: !root.busy
                opacity: root.busy ? 0.45 : 1
                labels: root.zoneLabels()
                currentIndex: Math.max(0, root.zoneLabels().indexOf(root.timezone))
                onPicked: (choice) => {
                    var names = root.zoneLabels()
                    if (choice < 0 || choice >= names.length || names[choice] === root.timezone)
                        return
                    root.busy = true
                    writeProc.run(["python3", root.script(), "timezone", names[choice]])
                }
            }
        }

        BodyText { width: parent.width; text: root.message; visible: root.message.length > 0 }
    }
}
