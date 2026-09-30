import QtQuick
import qs.components

Item {
    id: root
    property string wallpaper: ""
    property string colorName: "blue"
    property bool forcedColor: false
    property bool colorFromWallpaper: false
    property bool forcedBrightnessMode: false
    property string brightnessMode: "light"
    property string screensaver: "cycle"
    property var colors: ["red", "orange", "yellow", "green", "teal", "blue", "purple", "pink"]
    property var screensavers: ["none", "cycle", "random"]
    property bool busy: false
    property bool picking: false
    property bool loaded: false
    property bool pending: false
    property string message: ""

    function commit() {
        if (!loaded)
            return
        if (busy) {
            pending = true
            return
        }
        busy = true
        pending = false
        message = "Přepočítávám vzhled…"
        proc.run(["python3", script(), "apply", JSON.stringify({
            wallpaper: wallpaper,
            color: colorName,
            forcedColor: forcedColor,
            colorFromWallpaper: colorFromWallpaper,
            forcedBrightnessMode: forcedBrightnessMode,
            brightnessMode: brightnessMode,
            screensaver: screensaver
        })])
    }

    function pickWallpaper() {
        picking = true
        pickerProc.run([
            "zenity", "--file-selection", "--title=Tapeta",
            "--file-filter=Obrázky | *.png *.jpg *.jpeg *.webp *.bmp"
        ])
    }

    function script() { return Config.scripts + "/look.py" }

    function take(stdout, stderr) {
        busy = false
        var parsed = null
        try {
            parsed = JSON.parse(stdout)
        } catch (e) {
            message = (stderr || stdout || "Vzhled se nepodařilo načíst").trim()
            if (pending)
                commit()
            return
        }
        if (!parsed.ok) {
            message = parsed.error || "Uložení selhalo"
            pending = false
            return
        }
        if (pending) {
            commit()
            return
        }
        wallpaper = parsed.wallpaper
        colorName = parsed.color
        forcedColor = parsed.forcedColor
        colorFromWallpaper = parsed.colorFromWallpaper
        forcedBrightnessMode = parsed.forcedBrightnessMode
        brightnessMode = parsed.brightnessMode
        screensaver = parsed.screensaver
        colors = parsed.colors
        screensavers = parsed.screensavers
        loaded = true
        message = ""
    }

    Component.onCompleted: proc.run(["python3", script(), "status"])

    Proc {
        id: proc
        onFinished: (code, stdout, stderr) => root.take(stdout, stderr)
    }

    Proc {
        id: pickerProc
        onFinished: (code, stdout, stderr) => {
            root.picking = false
            if (code === 0) {
                var path = stdout.trim()
                if (path.startsWith("file://"))
                    path = decodeURIComponent(path.slice(7))
                if (path.length > 0 && path !== root.wallpaper) {
                    root.wallpaper = path
                    root.commit()
                }
                return
            }
            if (code !== 1)
                root.message = (stderr || "Zenity se nepodařilo spustit").trim()
        }
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Look & Feel"

        AeroCard {
            width: parent.width
            SectionLabel { text: "Tapeta"; width: parent.width }
            BodyText { width: parent.width; text: root.wallpaper; wrapMode: Text.WrapAnywhere }
            AeroButton {
                text: root.picking ? "Vybírám…" : "Vybrat soubor"
                enabled: !root.picking
                onClicked: root.pickWallpaper()
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Barva"; width: parent.width }
            Row {
                width: parent.width
                spacing: 12
                BodyText {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Vynutit barvu"
                }
                AeroSwitch {
                    checked: root.forcedColor
                    onClicked: {
                        root.forcedColor = !root.forcedColor
                        root.commit()
                    }
                }
            }
            BodyText {
                width: parent.width
                text: root.forcedColor
                      ? "Accent se vezme z vybrané barvy."
                      : "Bez vynucení se accent počítá z tapety."
            }
            AeroCombo {
                width: parent.width
                opacity: root.forcedColor ? 1 : 0.45
                enabled: root.forcedColor
                labels: root.colors
                currentIndex: Math.max(0, root.colors.indexOf(root.colorName))
                onPicked: (choice) => {
                    if (choice < 0 || choice >= root.colors.length)
                        return
                    if (root.colorName === root.colors[choice])
                        return
                    root.colorName = root.colors[choice]
                    root.commit()
                }
            }
            Row {
                width: parent.width
                spacing: 12
                BodyText {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Přesná barva z tapety"
                }
                AeroSwitch {
                    enabled: !root.forcedColor
                    checked: root.colorFromWallpaper
                    onClicked: {
                        root.colorFromWallpaper = !root.colorFromWallpaper
                        root.commit()
                    }
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Světlý a tmavý režim"; width: parent.width }
            Row {
                width: parent.width
                spacing: 12
                BodyText {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Vynutit režim"
                }
                AeroSwitch {
                    checked: root.forcedBrightnessMode
                    onClicked: {
                        root.forcedBrightnessMode = !root.forcedBrightnessMode
                        root.commit()
                    }
                }
            }
            BodyText {
                width: parent.width
                text: root.forcedBrightnessMode ? "Režim bere nastavení tady." : "Režim bere darkman podle denní doby."
            }
            Row {
                spacing: 8
                opacity: root.forcedBrightnessMode ? 1 : 0.4
                AeroButton {
                    text: "Světlý"
                    accent: false
                    selected: root.brightnessMode === "light"
                    enabled: root.forcedBrightnessMode
                    onClicked: {
                        if (root.brightnessMode === "light")
                            return
                        root.brightnessMode = "light"
                        root.commit()
                    }
                }
                AeroButton {
                    text: "Tmavý"
                    accent: false
                    selected: root.brightnessMode === "dark"
                    enabled: root.forcedBrightnessMode
                    onClicked: {
                        if (root.brightnessMode === "dark")
                            return
                        root.brightnessMode = "dark"
                        root.commit()
                    }
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Spořič"; width: parent.width }
            AeroCombo {
                width: parent.width
                labels: root.screensavers
                currentIndex: Math.max(0, root.screensavers.indexOf(root.screensaver))
                onPicked: (choice) => {
                    if (choice < 0 || choice >= root.screensavers.length)
                        return
                    if (root.screensaver === root.screensavers[choice])
                        return
                    root.screensaver = root.screensavers[choice]
                    root.commit()
                }
            }
        }

        BodyText { width: parent.width; text: root.message; visible: root.message.length > 0 }
    }
}
