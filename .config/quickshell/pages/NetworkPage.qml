import QtQuick
import qs.components

Item {
    id: root

    property var snapshot: ({ wifiEnabled: false, networks: [], saved: [], ethernet: [] })
    property bool busy: false
    property bool scanning: false
    property string message: ""
    property string pendingSsid: ""

    function script() { return Config.scripts + "/nm.py" }

    function take(code, stdout, stderr) {
        busy = false
        scanning = false
        var parsed = null
        try {
            parsed = JSON.parse(stdout)
        } catch (e) {
            message = (stderr || stdout || "Síť neodpověděla").trim()
            return
        }
        if (!parsed.ok) {
            message = parsed.error || "Akce selhala"
            return
        }
        snapshot = parsed
        message = ""
    }

    function refresh() {
        busy = true
        proc.run(["python3", script(), "status"])
    }

    function scan() {
        busy = true
        scanning = true
        message = "Hledám sítě…"
        proc.run(["python3", script(), "scan"])
    }

    Component.onCompleted: refresh()

    Proc {
        id: proc
        onFinished: (code, stdout, stderr) => root.take(code, stdout, stderr)
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Síť"

        AeroCard {
            width: parent.width
            Item {
                width: parent.width
                height: 42

                SectionLabel {
                    id: wifiLabel
                    text: "Wi-Fi"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: refreshButton
                    width: 36
                    height: 36
                    anchors.left: wifiLabel.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !root.busy && root.snapshot.wifiEnabled === true
                    opacity: enabled ? 1 : 0.45
                    scale: refreshMouse.pressed && enabled ? 0.94 : 1

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: refreshMouse.pressed && refreshButton.enabled ? 2 : 0
                        radius: height / 2
                        border.width: 1
                        border.color: Theme.line
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.sheen(refreshMouse.pressed ? 0.22 : 0.62) }
                            GradientStop { position: 0.46; color: refreshMouse.pressed ? Theme.gelDeep : Theme.gel }
                            GradientStop { position: 0.52; color: Theme.glassDeep }
                            GradientStop { position: 1; color: Theme.glassDeep }
                        }
                        AeroSheen { strength: refreshMouse.pressed ? 0.25 : 0.75 }
                    }

                    Item {
                        id: refreshGlyph
                        anchors.centerIn: parent
                        width: 20
                        height: 20

                        NumberAnimation {
                            target: refreshGlyph
                            property: "rotation"
                            running: root.scanning
                            from: 0
                            to: 360
                            duration: 700
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) refreshGlyph.rotation = 0
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf021"
                            color: Theme.ink
                            font.family: "Font Awesome 7 Free Solid"
                            font.pixelSize: 14
                            font.weight: 900
                        }
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        enabled: refreshButton.enabled
                        onClicked: root.scan()
                    }
                }

                Row {
                    id: switchRow
                    spacing: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    BodyText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.snapshot.wifiEnabled ? "Zapnuto" : "Vypnuto"
                    }
                    AeroSwitch {
                        checked: root.snapshot.wifiEnabled === true
                        enabled: !root.busy
                        onClicked: {
                            root.busy = true
                            proc.run(["python3", root.script(), "radio", root.snapshot.wifiEnabled ? "off" : "on"])
                        }
                    }
                }
            }
            BodyText {
                width: parent.width
                text: root.message
                visible: root.message.length > 0
            }
        }

        AeroCard {
            width: parent.width
            visible: root.snapshot.wifiEnabled === true
            SectionLabel { text: "Sítě v dosahu"; width: parent.width }
            BodyText {
                width: parent.width
                visible: !root.snapshot.networks || root.snapshot.networks.length === 0
                text: "Žádná síť. Zkuste hledání znovu."
            }
            Repeater {
                model: root.snapshot.networks || []
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 10
                    Column {
                        width: parent.width - 130
                        spacing: 2
                        Text {
                            width: parent.width
                            text: modelData.ssid + (modelData.inUse ? "  ·  připojeno" : "")
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: 640
                            elide: Text.ElideRight
                        }
                        BodyText {
                            width: parent.width
                            text: modelData.signal + " %  ·  " + (modelData.security || "otevřená")
                        }
                    }
                    AeroButton {
                        text: modelData.inUse ? "Připojeno" : "Připojit"
                        enabled: !modelData.inUse && !root.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            var open = !modelData.security || modelData.security === "--"
                            if (open) {
                                root.busy = true
                                proc.run(["python3", root.script(), "connect", modelData.ssid])
                            } else {
                                root.pendingSsid = modelData.ssid
                                passwordField.text = ""
                                passwordDialog.visible = true
                            }
                        }
                    }
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Uložená připojení"; width: parent.width }
            BodyText {
                width: parent.width
                visible: !root.snapshot.saved || root.snapshot.saved.length === 0
                text: "Žádné uložené připojení."
            }
            Repeater {
                model: root.snapshot.saved || []
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8
                    Column {
                        width: parent.width - 280
                        Text {
                            width: parent.width
                            text: modelData.name
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: 620
                            elide: Text.ElideRight
                        }
                        BodyText {
                            text: (modelData.type === "wifi" ? "Wi-Fi" : "Ethernet") + (modelData.active ? "  ·  aktivní" : "")
                        }
                    }
                    AeroButton {
                        text: modelData.active ? "Odpojit" : "Připojit"
                        accent: !modelData.active
                        enabled: !root.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            root.busy = true
                            proc.run(["python3", root.script(), modelData.active ? "down" : "up", modelData.name])
                        }
                    }
                    AeroButton {
                        text: "Zapomenout"
                        accent: false
                        enabled: !root.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            root.busy = true
                            proc.run(["python3", root.script(), "forget", modelData.name])
                        }
                    }
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Ethernet"; width: parent.width }
            BodyText {
                width: parent.width
                visible: !root.snapshot.ethernet || root.snapshot.ethernet.length === 0
                text: "Žádný ethernetový adaptér."
            }
            Repeater {
                model: root.snapshot.ethernet || []
                delegate: BodyText {
                    required property var modelData
                    width: parent.width
                    text: modelData.device + "  ·  " + modelData.state + (modelData.connection ? "  ·  " + modelData.connection : "")
                }
            }
        }
    }

    Rectangle {
        id: passwordDialog
        visible: false
        anchors.fill: parent
        color: Theme.tint(Theme.glassDeep, 0.45)
        radius: Theme.radius

        AeroCard {
            width: 420
            anchors.centerIn: parent
            SectionLabel { text: "Heslo k " + root.pendingSsid; width: parent.width; wrapMode: Text.WordWrap }
            AeroField {
                id: passwordField
                width: parent.width
                placeholder: "Heslo"
                password: true
                onAccepted: passwordDialog.connectNow()
            }
            Row {
                spacing: 10
                AeroButton {
                    text: "Připojit"
                    enabled: !root.busy
                    onClicked: passwordDialog.connectNow()
                }
                AeroButton {
                    text: "Zrušit"
                    accent: false
                    onClicked: passwordDialog.visible = false
                }
            }
        }

        function connectNow() {
            passwordDialog.visible = false
            root.busy = true
            proc.run(["python3", root.script(), "connect", root.pendingSsid, passwordField.text])
        }
    }
}
