// Render on Mesa (Intel iGPU, which drives the displays) without probing the
// nvidia EGL vendor first: glvnd would otherwise load ~35MB of nvidia libs
//@ pragma Env __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "." as Root

ShellRoot {
    id: shell

    Bar { id: bar }

    // Warm the app index and icon theme at startup. DesktopEntries scans
    // lazily on first access; without this the launcher's first open pays
    // ~200ms of scanning (and rebuilds its list once per entry found).
    Component.onCompleted: {
        DesktopEntries.applications
        Quickshell.iconPath("application-x-executable")
    }
    NotificationManager {}
    OSD {}

    // ── Lock ───────────────────────────────────────────────────────────────
    // The curtain animates here; the secure lock itself runs in its own
    // process (lock.qml), see LockCurtain.qml
    Loader {
        id: lockLoader
        active: Root.State.lockActive
        sourceComponent: LockCurtain {
            onFinished: Root.State.lockActive = false
        }
        onLoaded: item.lockDown()
    }
    function lock() {
        if (Root.State.lockActive) return
        activeModal = ""
        Root.State.lockActive = true
    }

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
                else if (cmd === "lock") shell.lock()
                else if (cmd === "lock-secure") lockLoader.item?.secured()
                else if (cmd === "lock-done") lockLoader.item?.liftUp()
            }
        }
    }
}
