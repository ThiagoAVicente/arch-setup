import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    id: shell

    Bar { id: bar }
    NotificationManager {}
    OSD {}

    // All modals lazy-unload to free memory. Only one open at a time:
    // opening another swaps it in, which unloads (closes) the previous one.
    property string activeModal: ""
    // Drawers grow out of the bar; swapping one for another morphs the
    // surface from the old size instead of dripping from scratch
    property int morphW: 0
    property int morphH: 0
    function drawerLoader(name) {
        return ({ launcher: launcherLoader, todo: todoLoader })[name] ?? null
    }
    function toggleModal(name) {
        if (activeModal !== name) {
            const out = drawerLoader(activeModal)?.item
            const swap = out && drawerLoader(name) && out.surface
            morphW = swap ? Math.round(out.surface.revealW) : 0
            morphH = swap ? Math.round(out.surface.revealH) : 0
            activeModal = name
            return
        }
        // Let drawers play their exit animation
        const item = drawerLoader(name)?.item
        if (item && item.close) item.close()
        else activeModal = ""
    }
    function seedMorph(item) {
        if (item.surface) {
            item.surface.fromW = morphW
            item.surface.fromH = morphH
        }
        morphW = morphH = 0
    }
    // Guarded so an outgoing modal's teardown can't clear the incoming one
    function modalClosed(name) {
        if (activeModal === name) activeModal = ""
    }

    Loader {
        id: launcherLoader
        active: shell.activeModal === "launcher"
        sourceComponent: Launcher {
            onVisibleChanged: if (!visible) shell.modalClosed("launcher")
        }
        onLoaded: if (item) { shell.seedMorph(item); item.toggle() }
    }
    Loader {
        id: wallpaperLoader
        active: shell.activeModal === "wallpaper"
        sourceComponent: WallpaperSelector {
            onVisibleChanged: if (!visible) shell.modalClosed("wallpaper")
        }
        onLoaded: if (item) item.toggle()
    }
    Loader {
        id: powerMenuLoader
        active: shell.activeModal === "powermenu"
        sourceComponent: PowerMenu {
            onVisibleChanged: if (!visible) shell.modalClosed("powermenu")
        }
        onLoaded: if (item) item.toggle()
    }
    Loader {
        id: todoLoader
        active: shell.activeModal === "todo"
        sourceComponent: Todo {
            onVisibleChanged: if (!visible) shell.modalClosed("todo")
        }
        onLoaded: if (item) { shell.seedMorph(item); item.toggle() }
    }

    Process {
        id: ipcServer
        running: true
        // Per-user runtime dir (0700) instead of world-writable /tmp
        command: ["sh", "-c", "s=\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/qs.sock\"; rm -f \"$s\"; exec nc -lkU \"$s\""]
        stdout: SplitParser {
            onRead: data => {
                const cmd = data.trim()
                if (["launcher", "wallpaper", "powermenu", "todo"].includes(cmd)) shell.toggleModal(cmd)
                else if (cmd === "bar") bar.toggleBar()
            }
        }
    }
}
