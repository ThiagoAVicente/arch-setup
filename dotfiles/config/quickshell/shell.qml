import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    id: shell

    Bar { id: bar }
    NotificationManager {}
    OSD {}

    // Modals lazy: Loader.active follows the modal's visible. Closing → unload → free memory.
    property bool launcherVisible: false
    property bool wallpaperVisible: false
    property bool powerMenuVisible: false
    property bool todoVisible: false

    Loader {
        id: launcherLoader
        active: shell.launcherVisible
        sourceComponent: Launcher {
            onVisibleChanged: if (!visible) shell.launcherVisible = false
        }
        onLoaded: if (item) item.toggle()
    }
    Loader {
        id: wallpaperLoader
        active: shell.wallpaperVisible
        sourceComponent: WallpaperSelector {
            onVisibleChanged: if (!visible) shell.wallpaperVisible = false
        }
        onLoaded: if (item) item.toggle()
    }
    Loader {
        id: powerMenuLoader
        active: shell.powerMenuVisible
        sourceComponent: PowerMenu {
            onVisibleChanged: if (!visible) shell.powerMenuVisible = false
        }
        onLoaded: if (item) item.toggle()
    }
    Loader {
        id: todoLoader
        active: shell.todoVisible
        sourceComponent: Todo {
            onVisibleChanged: if (!visible) shell.todoVisible = false
        }
        onLoaded: if (item) item.toggle()
    }

    Process {
        id: ipcServer
        running: true
        command: ["sh", "-c", "rm -f /tmp/qs.sock; nc -lkU /tmp/qs.sock"]
        stdout: SplitParser {
            onRead: data => {
                const cmd = data.trim()
                if (cmd === "launcher") shell.launcherVisible = !shell.launcherVisible
                else if (cmd === "wallpaper") shell.wallpaperVisible = !shell.wallpaperVisible
                else if (cmd === "powermenu") shell.powerMenuVisible = !shell.powerMenuVisible
                else if (cmd === "bar") bar.toggleBar()
                else if (cmd === "todo") shell.todoVisible = !shell.todoVisible
            }
        }
    }
}
