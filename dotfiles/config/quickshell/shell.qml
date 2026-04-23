//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "./Widget"

ShellRoot {
    id: shell



    Bar { id: bar }
    NotificationManager {}
    OSD {}
    Launcher { id: launcher }
    WallpaperSelector { id: wallpaperSelector }
    PowerMenu { id: powerMenu }
    //Clock {}

    // Simple: use socat to listen on socket
    Process {
        id: ipcServer
        running: true
        command: ["sh", "-c", "rm -f /tmp/qs.sock; nc -lkU /tmp/qs.sock"]
        stdout: SplitParser {
            onRead: data => {
                let cmd = data.trim()
                console.log("IPC:", cmd)
                if (cmd === "launcher") launcher.toggle()
                else if (cmd === "wallpaper") wallpaperSelector.toggle()
                else if (cmd === "powermenu") powerMenu.toggle()
                else if (cmd === "bar") bar.toggleBar()
            }
        }
    }
}
