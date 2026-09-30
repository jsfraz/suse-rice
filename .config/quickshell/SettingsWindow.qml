import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components

FloatingWindow {
    id: win
    title: "System Settings"
    implicitWidth: 960
    implicitHeight: 560
    minimumSize: Qt.size(800, 480)
    color: Theme.window
    visible: false

    property int pageIndex: 0
    property var pages: [
        { title: "Network", themeIcon: "preferences-system-network", file: "pages/NetworkPage.qml" },
        { title: "Bluetooth", themeIcon: "preferences-system-bluetooth", file: "pages/BluetoothPage.qml" },
        { title: "Displays", themeIcon: "preferences-desktop-display", file: "pages/DisplaysPage.qml" },
        { title: "Sound", themeIcon: "preferences-desktop-sound", file: "pages/SoundPage.qml" },
        { title: "Power", themeIcon: "preferences-system-power-management", file: "pages/PowerPage.qml" },
        { title: "Look & Feel", themeIcon: "preferences-desktop-theme", file: "pages/LookPage.qml" },
        { title: "Keyboard", themeIcon: "preferences-desktop-keyboard", file: "pages/KeyboardPage.qml" },
        { title: "Printers", themeIcon: "preferences-desktop-printer", file: "pages/PrinterPage.qml" },
        { title: "Date and time", themeIcon: "preferences-system-time", file: "pages/DateTimePage.qml" }
    ]

    property real reveal: 0

    function toggle() {
        if (visible) {
            dismiss()
            return
        }
        openFresh(0)
    }

    // The window stays loaded while hidden, so the last page and its scroll
    // would otherwise come back. Unload first, then show the requested page
    // from the top.
    function openFresh(index) {
        pages.active = false
        pageIndex = index
        pages.active = true
        visible = true
        focusTimer.restart()
    }

    function dismiss() {
        if (!visible || hideAnim.running)
            return
        hideAnim.restart()
    }

    onVisibleChanged: {
        if (visible)
            revealAnim.restart()
    }

    NumberAnimation {
        id: revealAnim
        target: win
        property: "reveal"
        from: 0
        to: 1
        duration: 280
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hideAnim
        target: win
        property: "reveal"
        to: 0
        duration: 160
        easing.type: Easing.InQuad
        onFinished: win.visible = false
    }

    onClosed: visible = false

    Component.onCompleted: Config.settingsWindow = win

    Shortcut {
        sequences: ["Escape"]
        enabled: win.visible
        context: Qt.WindowShortcut
        onActivated: win.dismiss()
    }

    Timer {
        id: focusTimer
        interval: 120
        onTriggered: focusProc.run(["hyprctl", "dispatch", "focuswindow", "title:^(System Settings)$"])
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
        anchors.margins: 10
        width: 210
        opacity: win.reveal
        transform: Translate { y: (1 - win.reveal) * 18 }
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
            height: 48
            onPressed: win.startSystemMove()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: "Settings"
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.weight: 650
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                id: navHost
                Layout.fillWidth: true
                Layout.preferredHeight: navCol.implicitHeight

                Rectangle {
                    id: pill
                    width: parent.width
                    height: 32
                    radius: Theme.radiusSm
                    y: {
                        var row = navCol.children[win.pageIndex]
                        return row ? row.y : 0
                    }
                    border.width: 1
                    border.color: Theme.highlight
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.sheen(0.55) }
                        GradientStop { position: 0.48; color: Theme.gloss(Theme.gelActive) }
                        GradientStop { position: 1; color: Theme.gelDeep }
                    }
                    Behavior on y {
                        enabled: win.visible
                        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                    }

                    AeroGlint { id: pillGlint }
                }

                Column {
                    id: navCol
                    width: parent.width
                    spacing: 4
                    z: 1

                    Repeater {
                        model: win.pages
                        delegate: Item {
                            id: row
                            required property int index
                            required property var modelData
                            width: navCol.width
                            height: 32

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSm
                                color: Theme.tint(Theme.highlight, area.containsMouse && win.pageIndex !== index ? 0.16 : 0)
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22
                                    height: 22
                                    scale: win.pageIndex === row.index ? 1.08 : 1
                                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                                    Image {
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 22
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                        sourceSize: Qt.size(32, 32)
                                        source: Icons.prefix + "/32x32/preferences/" + modelData.themeIcon + ".png"
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 30
                                    text: modelData.title
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: win.pageIndex === row.index ? 700 : 560
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: win.pageIndex = index
                            }
                        }
                    }
                }

                Connections {
                    target: win
                    function onPageIndexChanged() { pillGlint.play() }
                }
            }

            Item { Layout.fillHeight: true }

            AeroButton {
                text: "Close"
                accent: false
                Layout.fillWidth: true
                onClicked: win.dismiss()
            }
        }
    }

    Loader {
        id: pages
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 10
        source: win.pages[win.pageIndex].file

        property real pageReveal: 0
        opacity: win.reveal * pageReveal
        transform: Translate { y: (1 - pageReveal) * 18 }

        onStatusChanged: {
            if (status === Loader.Ready)
                pageAnim.restart()
        }

        NumberAnimation {
            id: pageAnim
            target: pages
            property: "pageReveal"
            from: 0
            to: 1
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    // Same top edge as waybar: 1px rim, then a 1px inset highlight.
    Item {
        anchors.fill: parent
        enabled: false
        z: 20
        AeroSheen { curve: 16; strength: 0.62; color: Theme.rim; inset: 0 }
        AeroSheen { curve: 16; strength: 0.42; inset: 1 }
    }
}
