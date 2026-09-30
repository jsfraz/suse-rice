import Quickshell
import Quickshell.Io

Scope {
    SettingsWindow {
        id: settings
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            settings.toggle()
        }

        function showPage(index: int): void {
            if (settings.visible)
                settings.pageIndex = index
            else
                settings.openFresh(index)
        }
    }
}
