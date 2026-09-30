import QtQuick
import qs.components

Item {
    id: root
    property bool available: false
    property string hint: ""
    property var printers: []
    property var jobs: []
    property string defaultPrinter: ""
    property bool busy: false
    property string message: ""
    property string newName: ""
    property string newUri: ""

    function script() { return Config.scripts + "/cups.py" }

    function take(stdout, stderr) {
        busy = false
        var parsed = null
        try {
            parsed = JSON.parse(stdout)
        } catch (e) {
            message = (stderr || stdout || "Tiskárny se nepodařilo načíst").trim()
            return
        }
        if (!parsed.ok) {
            message = parsed.error || "Akce selhala"
            return
        }
        available = parsed.available === true
        hint = parsed.hint || ""
        printers = parsed.printers || []
        jobs = parsed.jobs || []
        defaultPrinter = parsed.default || ""
        message = ""
    }

    function refresh() {
        proc.run(["python3", script(), "status"])
    }

    Component.onCompleted: refresh()

    Proc {
        id: proc
        onFinished: (code, stdout, stderr) => root.take(stdout, stderr)
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Tiskárna"

        AeroCard {
            width: parent.width
            visible: !root.available
            SectionLabel { text: "CUPS"; width: parent.width }
            BodyText { width: parent.width; text: root.hint || "CUPS není nainstalovaný." }
        }

        AeroCard {
            width: parent.width
            visible: root.available
            SectionLabel {
                width: parent.width
                text: "Tiskárny" + (root.defaultPrinter ? "  ·  výchozí " + root.defaultPrinter : "")
            }
            BodyText {
                width: parent.width
                visible: root.printers.length === 0
                text: "Žádná tiskárna."
            }
            Repeater {
                model: root.printers
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 8
                    Text {
                        width: parent.width
                        text: modelData.name + (modelData.name === root.defaultPrinter ? "  ·  výchozí" : "")
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: 640
                    }
                    BodyText { text: modelData.enabled ? "Zapnutá" : "Pozastavená" }
                    Flow {
                        width: parent.width
                        spacing: 8
                        AeroButton {
                            text: "Výchozí"
                            enabled: modelData.name !== root.defaultPrinter && !root.busy
                            onClicked: {
                                root.busy = true
                                proc.run(["python3", root.script(), "default", modelData.name])
                            }
                        }
                        AeroButton {
                            text: modelData.enabled ? "Pozastavit" : "Zapnout"
                            accent: false
                            enabled: !root.busy
                            onClicked: {
                                root.busy = true
                                proc.run(["python3", root.script(), modelData.enabled ? "disable" : "enable", modelData.name])
                            }
                        }
                        AeroButton {
                            text: "Smazat"
                            accent: false
                            enabled: !root.busy
                            onClicked: {
                                root.busy = true
                                proc.run(["python3", root.script(), "delete", modelData.name])
                            }
                        }
                    }
                }
            }
        }

        AeroCard {
            width: parent.width
            visible: root.available
            SectionLabel { text: "Fronta"; width: parent.width }
            BodyText {
                width: parent.width
                visible: root.jobs.length === 0
                text: "Fronta je prázdná."
            }
            Repeater {
                model: root.jobs
                delegate: BodyText {
                    required property string modelData
                    width: parent.width
                    text: modelData
                }
            }
        }

        AeroCard {
            width: parent.width
            visible: root.available
            SectionLabel { text: "Přidat IPP"; width: parent.width }
            BodyText { width: parent.width; text: "Název bez mezer a adresa, třeba ipp://tiskarna.local/ipp/print." }
            AeroField {
                width: parent.width
                placeholder: "Název"
                onTextChanged: root.newName = text
            }
            AeroField {
                width: parent.width
                placeholder: "ipp://…"
                onTextChanged: root.newUri = text
            }
            AeroButton {
                text: "Přidat"
                enabled: !root.busy && root.newName.length > 0 && root.newUri.length > 0
                onClicked: {
                    root.busy = true
                    proc.run(["python3", root.script(), "add", root.newName, root.newUri])
                }
            }
        }

        BodyText { width: parent.width; text: root.message; visible: root.message.length > 0 }
    }
}
