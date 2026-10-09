pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "bar/widgets"
import "." as Root

// One screen of the lock: a curtain pulled down by the bar. Shared by the
// main shell (descent/ascent over the live desktop) and the lock process
// (secure surface). At progress 1 / morph 1 / no input both render the exact
// same frame, so handing over between them is invisible.
Item {
    id: scene

    // 0 = bar at its normal spot, 1 = landed at the bottom, screen covered
    property real progress: 0
    // 0 = workspace dots, 1 = padlock
    property real morph: 0
    // Bar starts above the screen when it isn't visible (fullscreen window)
    property bool barVisible: true
    property int dots: 0
    // idle | checking | fail
    property string status: "idle"
    property string message: ""

    readonly property int thickness: Root.Theme.barThickness
    readonly property int startY: barVisible ? Root.Theme.barMarginTop : -thickness - 2
    readonly property int endY: height - Root.Theme.barMarginTop - thickness
    readonly property real barY: startY + (endY - startY) * progress

    function shake() { shakeAnim.restart() }

    // ── Curtain ────────────────────────────────────────────────────────────
    // Covers everything above the bar; the last strip under the bar closes
    // as the bar lands so the final frame is fully opaque.
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Math.min(scene.height, scene.barY + scene.thickness / 2
            + (scene.height - scene.endY - scene.thickness / 2) * Math.max(0, scene.progress - 0.9) / 0.1)
        visible: scene.progress > 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#09090b" }
            GradientStop { position: 1.0; color: Root.Theme.panelSolid }
        }
    }

    // Faint lock watermark in the middle of the curtain once it's down
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        text: "󰌾"
        font.family: Root.Theme.fontFamily
        font.pixelSize: 96
        color: Qt.rgba(1, 1, 1, 0.05)
        opacity: Math.max(0, (scene.progress - 0.7) / 0.3)
        renderType: Text.NativeRendering
    }

    // ── Bar replica ────────────────────────────────────────────────────────
    Rectangle {
        id: pill
        x: Root.Theme.barMarginSide
        y: Math.round(scene.barY)
        width: scene.width - 2 * Root.Theme.barMarginSide
        height: scene.thickness
        radius: height / 2
        color: Root.Theme.barBg
        border.color: Root.Theme.hairline
        border.width: 1

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: parent.radius; rightMargin: parent.radius }
            height: 1
            color: Root.Theme.panelHi
        }

        Item {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 8 }
            width: clk.implicitWidth
            ClockCalendarWidget { id: clk; anchors.verticalCenter: parent.verticalCenter }
        }

        // Centre: workspace dots melt into the padlock + password dots
        Item {
            id: centre
            anchors.centerIn: parent
            width: Math.max(ws.implicitWidth * (1 - scene.morph), lockRow.implicitWidth * scene.morph)
            height: parent.height

            Loader {
                id: ws
                anchors.centerIn: parent
                active: scene.morph < 1
                opacity: 1 - scene.morph
                scale: 1 - 0.4 * scene.morph
                sourceComponent: HyprlandWorkspaces {}
            }

            Row {
                id: lockRow
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: shakeX
                property real shakeX: 0
                spacing: 8
                opacity: scene.morph
                scale: 0.6 + 0.4 * scene.morph

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: 15
                    renderType: Text.NativeRendering
                    color: scene.status === "fail" ? Root.Theme.critical : Root.Theme.barText
                    Behavior on color { ColorAnimation { duration: 150 } }
                    SequentialAnimation on opacity {
                        running: scene.status === "checking"
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.35; duration: 380; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 380; easing.type: Easing.InOutSine }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    visible: scene.dots > 0
                    Repeater {
                        model: Math.min(scene.dots, 24)
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: scene.status === "fail" ? Root.Theme.critical : Root.Theme.barText
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: scene.message !== "" && scene.dots === 0
                    text: scene.message
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                    color: Root.Theme.critical
                }
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: lockRow; property: "shakeX"; to: -9; duration: 50 }
                NumberAnimation { target: lockRow; property: "shakeX"; to: 8;  duration: 70 }
                NumberAnimation { target: lockRow; property: "shakeX"; to: -5; duration: 70 }
                NumberAnimation { target: lockRow; property: "shakeX"; to: 3;  duration: 60 }
                NumberAnimation { target: lockRow; property: "shakeX"; to: 0;  duration: 50 }
            }
        }

        RowLayout {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 8 }
            spacing: 2
            CpuWidget {}
            BatteryWidget {}
            VolumeWidget {}
            Item { Layout.preferredWidth: 10 }
            NetworkWidget {}
            BluetoothWidget {}
            Item { Layout.preferredWidth: 10 }
            NotificationsToggle {}
        }
    }

    // Display only: nothing on the lock reacts to the mouse
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onWheel: wheel => wheel.accepted = true
    }
}
