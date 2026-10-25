// One render thread and GL context for all windows instead of one per
// window: ~60MB less with the NVIDIA driver
//@ pragma Env QSG_RENDER_LOOP=basic
// jemalloc (quickshell is linked with it): hand freed memory back to the
// system within a second, one arena
//@ pragma Env MALLOC_CONF=narenas:1,dirty_decay_ms:1000,muzzy_decay_ms:0,tcache:false
// The EGL driver (NVIDIA or Mesa, whichever GPU drives the screens) is picked
// by ~/scripts/qs-start.sh
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

    // All modals lazy-unload to free memory. Only one open at a time:
    // opening another swaps it in, which unloads (closes) the previous one.
    property string activeModal: ""
    // Drawers grow out of the bar; swapping one for another morphs the
    // surface from the old size instead of dripping from scratch
    property int morphW: 0
    property int morphH: 0
    // Outgoing drawer kept loaded until the incoming one is on screen
    property string handoffModal: ""
    function drawerLoader(name) {
        return ({ launcher: launcherLoader, todo: todoLoader, wallpaper: wallpaperLoader })[name] ?? null
    }
    function toggleModal(name) {
        if (name === handoffModal) return
        if (activeModal !== name) {
            const out = drawerLoader(activeModal)?.item
            const swap = out && drawerLoader(name) && out.surface
            morphW = swap ? Math.round(out.surface.revealW) : 0
            morphH = swap ? Math.round(out.surface.revealH) : 0
            handoffModal = swap ? activeModal : ""
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
            const out = drawerLoader(handoffModal)?.item
            // Only morph within one monitor; across monitors the old drawer
            // drains on its screen while the new one drips on the other
            const same = out && out.surface && out.surface.screen === item.surface.screen
            item.surface.fromW = same ? morphW : 0
            item.surface.fromH = same ? morphH : 0
            if (same) out.surface.handOff(item.surface.fullW, item.surface.fullH)
            else if (out && out.close) out.close()
        }
        morphW = morphH = 0
    }
    // Guarded so an outgoing modal's teardown can't clear the incoming one
    function modalClosed(name) {
        if (activeModal === name) activeModal = ""
        if (handoffModal === name) handoffModal = ""
    }

    Loader {
        id: launcherLoader
        active: shell.activeModal === "launcher" || shell.handoffModal === "launcher"
        sourceComponent: Launcher {
            onVisibleChanged: if (!visible) shell.modalClosed("launcher")
        }
        onLoaded: if (item) { shell.seedMorph(item); item.toggle() }
    }
    Loader {
        id: wallpaperLoader
        active: shell.activeModal === "wallpaper" || shell.handoffModal === "wallpaper"
        sourceComponent: WallpaperSelector {
            onVisibleChanged: if (!visible) shell.modalClosed("wallpaper")
        }
        onLoaded: if (item) { shell.seedMorph(item); item.toggle() }
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
        active: shell.activeModal === "todo" || shell.handoffModal === "todo"
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
                else if (cmd === "recording") Root.Recording.refresh()
            }
        }
    }
}
