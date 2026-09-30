import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.components

Item {
    id: root
    property bool bluemanChecked: false
    property bool bluemanReady: false

    function openBlueman() {
        if (!bluemanReady)
            return
        Quickshell.execDetached(["blueman-manager"])
        Config.dismissSettings()
    }

    Component.onCompleted: whichProc.run(["sh", "-c", "command -v blueman-manager"])

    Proc {
        id: whichProc
        onFinished: (code, stdout) => {
            root.bluemanChecked = true
            root.bluemanReady = code === 0 && stdout.trim().length > 0
        }
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Bluetooth"

        AeroCard {
            width: parent.width
            visible: Bluetooth.defaultAdapter === null
            SectionLabel { text: "Adaptér není k dispozici"; width: parent.width }
            BodyText {
                width: parent.width
                text: "Nainstalujte bluez a spusťte Bluetooth."
            }
        }

        AeroCard {
            width: parent.width
            visible: Bluetooth.defaultAdapter !== null
            SectionLabel { text: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.name : ""; width: parent.width }

            Row {
                width: parent.width
                spacing: 12
                BodyText {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Zapnuto"
                }
                AeroSwitch {
                    checked: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
                    onClicked: {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 12
                BodyText {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Viditelný pro ostatní"
                }
                AeroSwitch {
                    enabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
                    checked: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discoverable : false
                    onClicked: {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.discoverable = !Bluetooth.defaultAdapter.discoverable
                    }
                }
            }
        }

        AeroButton {
            text: "Nastavení"
            enabled: root.bluemanReady
            onClicked: root.openBlueman()
        }

        BodyText {
            width: parent.width
            visible: root.bluemanChecked && !root.bluemanReady
            text: "Párování řeší Blueman. Nainstalujte ho příkazem: sudo zypper in blueman"
        }
    }
}
