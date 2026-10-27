pragma ComponentBehavior: Bound

// The battery as a bubble (island/mod.rs:162 BUBBLE 48): its charge as a
// ring in the battery's colour, the percentage inside.

import QtQuick
import qs
import qs.services
import qs.components

Item {
    id: root

    property real targetWidth: Theme.bubbleSize
    property real targetHeight: Theme.bubbleSize

    anchors.fill: parent

    ProgressRing {
        anchors.centerIn: parent
        size: Theme.compactRing
        width: Theme.compactRing
        height: Theme.compactRing
        progress: Power.percentage
        color: Power.colour

        Text {
            anchors.centerIn: parent
            text: Power.percent
            color: Theme.label
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.compactRing * 0.36)
            font.weight: Font.DemiBold
        }
    }
}
