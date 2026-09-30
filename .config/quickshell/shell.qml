import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.components

Scope {
    SettingsWindow {
        id: settings
    }

    function closeOverlays() {
        settings.dismiss()
        Quickshell.execDetached([Config.scripts + "/close-app-launcher.sh"])
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "workspacev2" || event.name === "activespecial")
                closeOverlays()
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            settings.toggle()
        }

        function hide(): void {
            settings.dismiss()
        }

        function showPage(index: int): void {
            if (settings.visible)
                settings.pageIndex = index
            else
                settings.openFresh(index)
        }
    }
}
