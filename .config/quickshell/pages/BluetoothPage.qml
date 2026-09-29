import QtQuick
import Quickshell.Bluetooth
import qs.components

Item {
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

            AeroButton {
                text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? "Zastavit hledání" : "Hledat zařízení"
                enabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
                onClicked: {
                    if (Bluetooth.defaultAdapter)
                        Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering
                }
            }
        }

        AeroCard {
            width: parent.width
            visible: Bluetooth.defaultAdapter !== null
            SectionLabel { text: "Zařízení"; width: parent.width }
            BodyText {
                width: parent.width
                visible: deviceRepeater.count === 0
                text: "Žádné zařízení. Zapněte hledání a dejte druhou stranu do párovacího režimu."
            }
            Repeater {
                id: deviceRepeater
                model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : 0
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    Text {
                        width: parent.width
                        text: (modelData.name || modelData.deviceName || modelData.address)
                              + (modelData.connected ? "  ·  připojeno" : (modelData.paired ? "  ·  spárováno" : ""))
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: 640
                        elide: Text.ElideRight
                    }
                    BodyText {
                        visible: modelData.batteryAvailable
                        text: "Baterie " + Math.round(modelData.battery * 100) + " %"
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        AeroButton {
                            text: modelData.connected ? "Odpojit" : (modelData.paired ? "Připojit" : "Párovat")
                            onClicked: {
                                if (modelData.connected)
                                    modelData.disconnect()
                                else if (modelData.paired)
                                    modelData.connect()
                                else
                                    modelData.pair()
                            }
                        }
                        AeroButton {
                            text: "Zapomenout"
                            accent: false
                            visible: modelData.paired || modelData.bonded
                            onClicked: modelData.forget()
                        }
                        Row {
                            spacing: 8
                            visible: modelData.paired
                            BodyText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Důvěryhodné"
                            }
                            AeroSwitch {
                                checked: modelData.trusted
                                onClicked: modelData.trusted = !modelData.trusted
                            }
                        }
                    }
                }
            }
        }
    }
}
