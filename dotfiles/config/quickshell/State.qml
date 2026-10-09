pragma Singleton
import QtQuick

QtObject {
    property bool notificationsMuted: false
    property string appliedWallpaper: ""
    property bool barHidden: false
    // Lock curtain owns the bar while true (real bar pill is hidden)
    property bool lockActive: false
}
