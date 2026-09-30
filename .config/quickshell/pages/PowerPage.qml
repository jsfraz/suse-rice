import QtQuick
import Quickshell.Services.UPower
import qs.components

Item {
    id: root
    property int brightness: -1
    property int idleKbd: 150
    property int idleScreensaver: 600
    property int idleLock: 3600
    property bool busy: false
    property string message: ""

    function script() { return Config.scripts + "/power.py" }

    function minutes(seconds) {
        var m = seconds / 60
        if (Math.abs(m - Math.round(m)) < 0.05)
            return Math.round(m) + " min"
        return m.toFixed(1) + " min"
    }

    function take(stdout, stderr) {
        busy = false
        var parsed = null
        try {
            parsed = JSON.parse(stdout)
        } catch (e) {
            message = (stderr || stdout || "Napájení se nepodařilo načíst").trim()
            return
        }
        if (!parsed.ok) {
            message = parsed.error || "Akce selhala"
            return
        }
        brightness = parsed.brightness === null || parsed.brightness === undefined ? -1 : parsed.brightness
        idleKbd = parsed.idleKbd
        idleScreensaver = parsed.idleScreensaver
        idleLock = parsed.idleLock
        message = ""
    }

    Component.onCompleted: proc.run(["python3", script(), "status"])

    Proc {
        id: proc
        onFinished: (code, stdout, stderr) => root.take(stdout, stderr)
    }

    Page {
        anchors.fill: parent
        anchors.rightMargin: 12
        heading: "Napájení"

        AeroCard {
            width: parent.width
            SectionLabel { text: "Baterie"; width: parent.width }
            BodyText {
                width: parent.width
                text: {
                    var device = UPower.displayDevice
                    if (!device || !device.ready)
                        return "UPower neběží. Nainstalujte ho příkazem: sudo zypper in upower"
                    // This quickshell build exposes UPower's percentage as 0–1.
                    var pct = device.percentage
                    if (pct <= 1)
                        pct *= 100
                    return (UPower.onBattery ? "Na baterii" : "Na napájení") + "  ·  " + Math.round(pct) + " %"
                }
            }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Profil"; width: parent.width }
            Row {
                spacing: 10
                AeroButton {
                    visible: PowerProfiles.hasPerformanceProfile
                    text: "Výkon"
                    accent: PowerProfiles.profile === PowerProfile.Performance
                    onClicked: PowerProfiles.profile = PowerProfile.Performance
                }
                AeroButton {
                    text: "Rovnováha"
                    accent: PowerProfiles.profile === PowerProfile.Balanced
                    onClicked: PowerProfiles.profile = PowerProfile.Balanced
                }
                AeroButton {
                    text: "Úsporný"
                    accent: PowerProfiles.profile === PowerProfile.PowerSaver
                    onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
                }
            }
        }

        AeroCard {
            width: parent.width
            visible: root.brightness >= 0
            SectionLabel { text: "Jas displeje"; width: parent.width }
            BodyText { text: root.brightness + " %" }
            AeroSlider {
                width: parent.width
                from: 2
                to: 100
                step: 1
                value: Math.max(2, root.brightness)
                onMoved: (v) => {
                    root.brightness = v
                    proc.run(["python3", root.script(), "brightness", String(v)])
                }
            }
        }

        AeroCard {
            width: parent.width
            visible: root.brightness < 0
            BodyText { width: parent.width; text: "Podsvícení se nenašlo (brightnessctl)." }
        }

        AeroCard {
            width: parent.width
            SectionLabel { text: "Nečinnost"; width: parent.width }
            BodyText { text: "Podsvícení klávesnice  ·  " + root.minutes(root.idleKbd) }
            AeroSlider {
                width: parent.width
                from: 30
                to: 900
                step: 30
                value: root.idleKbd
                onMoved: (v) => root.idleKbd = v
            }

            BodyText { text: "Spořič obrazovky  ·  " + root.minutes(root.idleScreensaver) }
            AeroSlider {
                width: parent.width
                from: 60
                to: 3600
                step: 60
                value: root.idleScreensaver
                onMoved: (v) => root.idleScreensaver = v
            }

            BodyText { text: "Zámek a zhasnutí panelu  ·  " + root.minutes(root.idleLock) }
            AeroSlider {
                width: parent.width
                from: 300
                to: 14400
                step: 60
                value: root.idleLock
                onMoved: (v) => root.idleLock = v
            }

            AeroButton {
                text: root.busy ? "Ukládám…" : "Použít časy"
                enabled: !root.busy
                onClicked: {
                    root.busy = true
                    idleProc.run(["python3", root.script(), "idle", JSON.stringify({
                        idleKbd: root.idleKbd,
                        idleScreensaver: root.idleScreensaver,
                        idleLock: root.idleLock
                    })])
                }
            }
            BodyText { width: parent.width; text: root.message; visible: root.message.length > 0 }
        }
    }

    Proc {
        id: idleProc
        onFinished: (code, stdout, stderr) => root.take(stdout, stderr)
    }
}
