import QtQuick

// Drag handle: a 3×2 grid of dots, laid across the bar (2×3 on a side bar)
Grid {
    id: dots
    property bool vertical: false
    property color color: "white"

    // Columns only: setting rows too passes through a 2×2 grid mid-switch
    columns: vertical ? 2 : 3
    spacing: 3

    Repeater {
        model: 6
        Rectangle {
            width: 3; height: 3; radius: 1.5
            color: dots.color
        }
    }
}
