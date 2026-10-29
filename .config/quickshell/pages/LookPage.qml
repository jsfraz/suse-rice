import QtQuick
import qs.components

Item {
    id: root
    property string wallpaper: ""
    property string colorName: "blue"
    property bool autoColor: true
    property bool colorFromWallpaper: false
    property bool autoBrightnessMode: true
    property string brightnessMode: "light"
    property string screensaver: "cycle"
    property var colors: ["red", "orange", "yellow", "green", "teal", "blue", "purple", "pink"]
    property var screensavers: ["none", "cycle", "random"]
    property bool busy: false
    property bool picking: false
    property bool loaded: false
    property bool pending: false

    function commit() {
        if (!loaded)
            return
        if (busy) {
            pending = true
            return
        }
        busy = true
        pending = false
        proc.run(["python3", script(), "apply", JSON.stringify({
            wallpaper: wallpaper,
            color: colorName,
            autoColor: autoColor,
            colorFromWallpaper: colorFromWallpaper,
            autoBrightnessMode: autoBrightnessMode,
            brightnessMode: brightnessMode,
            screensaver: screensaver
        })])
    }

    function pickWallpaper() {
        picking = true
        pickerProc.run([
            "zenity", "--file-selection", "--title=Wallpaper",
            "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.bmp"
        ])
    }

    function script() { return Config.scripts + "/look.py" }

    function take(stdout, stderr) {
        busy = false
        var parsed = null
        try {
            parsed = JSON.parse(stdout)
        } catch (e) {
            Config.notifyError((stderr || stdout || "Could not load the look").trim(), "Look & Feel")
            if (pending)
                commit()
            return
        }
        if (!parsed.ok) {
            Config.notifyError(parsed.error || "Save failed", "Look & Feel")
            pending = false
            return
        }
        if (pending) {
            commit()
            return
        }
        wallpaper = parsed.wallpaper
        colorName = parsed.color
        autoColor = parsed.autoColor
        colorFromWallpaper = parsed.colorFromWallpaper
        autoBrightnessMode = parsed.autoBrightnessMode
        brightnessMode = parsed.brightnessMode
        screensaver = parsed.screensaver
        colors = parsed.colors
        screensavers = parsed.screensavers
        loaded = true
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
                Config.notifyError((stderr || "Could not start Zenity").trim(), "Look & Feel")
        }
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Look & Feel"

        AeroCard {
            width: parent.width
            SectionLabel { text: "Wallpaper"; width: parent.width }
            BodyText { width: parent.width; text: root.wallpaper; wrapMode: Text.WrapAnywhere }
            AeroButton {
                text: root.picking ? "Choosing…" : "Choose file"
                enabled: !root.picking
                onClicked: root.pickWallpaper()
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Color"; width: parent.width }
            Row {
                width: parent.width
                spacing: 12
                BodyText {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Automatic color"
                }
                AeroSwitch {
                    checked: root.autoColor
                    onClicked: {
                        root.autoColor = !root.autoColor
                        root.commit()
                    }
                }
            }
            BodyText {
                width: parent.width
                text: root.autoColor
                      ? "The accent is taken from the wallpaper."
                      : "The accent comes from the chosen color."
            }
            AeroCombo {
                width: parent.width
                opacity: root.autoColor ? 0.45 : 1
                enabled: !root.autoColor
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
                    text: "Exact color from the wallpaper"
                }
                AeroSwitch {
                    enabled: root.autoColor
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
            SectionLabel { text: "Light and dark mode"; width: parent.width }
            Row {
                width: parent.width
                spacing: 12
                BodyText {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Automatic mode"
                }
                AeroSwitch {
                    checked: root.autoBrightnessMode
                    onClicked: {
                        root.autoBrightnessMode = !root.autoBrightnessMode
                        root.commit()
                    }
                }
            }
            BodyText {
                width: parent.width
                text: root.autoBrightnessMode ? "The mode follows darkman by time of day." : "The mode uses the setting below."
            }
            Row {
                spacing: 8
                opacity: root.autoBrightnessMode ? 0.4 : 1
                AeroButton {
                    text: "Light"
                    accent: false
                    selected: root.brightnessMode === "light"
                    enabled: !root.autoBrightnessMode
                    onClicked: {
                        if (root.brightnessMode === "light")
                            return
                        root.brightnessMode = "light"
                        root.commit()
                    }
                }
                AeroButton {
                    text: "Dark"
                    accent: false
                    selected: root.brightnessMode === "dark"
                    enabled: !root.autoBrightnessMode
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
            SectionLabel { text: "Screensaver"; width: parent.width }
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

    }
}
