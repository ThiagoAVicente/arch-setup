pragma Singleton
import QtQuick

QtObject {
    property bool notificationsMuted: false
    property string appliedWallpaper: ""
    property bool barHidden: false
    // A drawer (launcher, todo, wallpaper) is open; set by shell.qml
    property bool drawerOpen: false
}
