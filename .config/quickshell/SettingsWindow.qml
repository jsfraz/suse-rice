import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components

FloatingWindow {
    id: win
    title: "Nastavení systému"
    implicitWidth: 1120
    implicitHeight: 740
    minimumSize: Qt.size(900, 600)
    color: Theme.window
    visible: false

    property int pageIndex: 0
    property var pages: [
        { title: "Síť", icon: "\uf1eb", font: "Font Awesome 7 Free Solid", file: "pages/NetworkPage.qml" },
        { title: "Bluetooth", icon: "\uf294", font: "Font Awesome 7 Brands", file: "pages/BluetoothPage.qml" },
        { title: "Displeje", icon: "\uf108", font: "Font Awesome 7 Free Solid", file: "pages/DisplaysPage.qml" },
        { title: "Zvuk", icon: "\uf028", font: "Font Awesome 7 Free Solid", file: "pages/SoundPage.qml" },
        { title: "Napájení", icon: "\uf0e7", font: "Font Awesome 7 Free Solid", file: "pages/PowerPage.qml" },
        { title: "Look & Feel", icon: "\uf53f", font: "Font Awesome 7 Free Solid", file: "pages/LookPage.qml" },
        { title: "Klávesnice", icon: "\uf11c", font: "Font Awesome 7 Free Solid", file: "pages/KeyboardPage.qml" },
        { title: "Tiskárny", icon: "\uf02f", font: "Font Awesome 7 Free Solid", file: "pages/PrinterPage.qml" },
        { title: "Datum a čas", icon: "\uf017", font: "Font Awesome 7 Free Solid", file: "pages/DateTimePage.qml" }
    ]

    function toggle() {
        if (visible) {
            visible = false
            return
        }
        visible = true
        focusTimer.restart()
    }

    onClosed: visible = false

    Shortcut {
        sequences: ["Escape"]
        enabled: win.visible
        context: Qt.WindowShortcut
        onActivated: win.visible = false
    }

    Timer {
        id: focusTimer
        interval: 120
        onTriggered: focusProc.run(["hyprctl", "dispatch", "focuswindow", "title:^(Nastavení systému)$"])
    }

    Proc { id: focusProc }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheen(0.28) }
            GradientStop { position: 0.18; color: Theme.sheen(0.06) }
            GradientStop { position: 0.46; color: Theme.tint(Theme.glass, 0.02) }
            GradientStop { position: 1; color: Theme.tint(Theme.glassDeep, 0.22) }
        }
    }

    // Soft orbs behind the panels, the way Aero glass used to catch the light.
    Repeater {
        model: [
            { x: 40, y: 30, d: 180, c: Theme.sheen(0.14) },
            { x: 860, y: 80, d: 240, c: Theme.tint(Theme.gelActive, 0.16) },
            { x: 700, y: 480, d: 200, c: Theme.tint(Theme.gel, 0.14) }
        ]
        delegate: Rectangle {
            x: modelData.x
            y: modelData.y
            width: modelData.d
            height: modelData.d
            radius: width / 2
            color: modelData.c
        }
    }

    Rectangle {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 16
        width: 250
        radius: Theme.radius
        border.width: 1
        border.color: Theme.line
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.sheen(0.34) }
            GradientStop { position: 0.18; color: Theme.sidebar }
            GradientStop { position: 1; color: Theme.tint(Theme.glassDeep, 0.82) }
        }

        AeroSheen { curve: Theme.radius; strength: 0.7 }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 72
            onPressed: win.startSystemMove()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Nastavení"
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 26
                font.weight: 650
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: win.pages
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: Theme.radiusSm
                    border.width: 1
                    border.color: win.pageIndex === index ? Theme.highlight : Theme.tint(Theme.rim, 0.4)
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Theme.sheen(win.pageIndex === index ? 0.55 : 0.22)
                        }
                        GradientStop {
                            position: 0.48
                            color: win.pageIndex === index ? Theme.gelActive : Theme.tint(Theme.gel, 0.28)
                        }
                        GradientStop {
                            position: 1
                            color: win.pageIndex === index ? Theme.gelDeep : Theme.tint(Theme.glassDeep, 0.35)
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            radius: 14
                            gradient: Gradient {
                                GradientStop { position: 0; color: Theme.highlight }
                                GradientStop { position: 0.45; color: Theme.gel }
                                GradientStop { position: 1; color: Theme.gelDeep }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: Theme.ink
                                font.family: modelData.font
                                font.pixelSize: 13
                                font.weight: modelData.font.indexOf("Solid") >= 0 ? 900 : 400
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 38
                            text: modelData.title
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: 620
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: win.pageIndex = index
                    }
                }
            }

            Item { Layout.fillHeight: true }

            AeroButton {
                text: "Zavřít"
                accent: false
                Layout.fillWidth: true
                onClicked: win.visible = false
            }
        }
    }

    Loader {
        id: pages
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 16
        source: win.pages[win.pageIndex].file
    }
}
