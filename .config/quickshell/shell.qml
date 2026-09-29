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
            settings.pageIndex = index
            if (!settings.visible)
                settings.visible = true
        }
    }
}
