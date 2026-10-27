pragma ComponentBehavior: Bound

// Expanded battery card (crates/shoji-island/src/island/battery.rs expanded):
// the ring with the device inside, what is happening over the device's
// name, the percentage at the right. (No "other batteries" line: this port
// reads UPower's display device only, so the card stays 84 tall.)

import QtQuick
import Quickshell
import qs
import qs.services
import qs.components

Item {
    id: root

    // mod.rs:169 EXPANDED.0, battery.rs:25 EXPANDED_HEIGHT, mod.rs:171 EXPANDED_RADIUS
    property real targetWidth: Theme.expandedWidth
    property real targetHeight: Theme.batteryExpandedHeight
    property real targetRadius: Theme.expandedRadius

    // battery.rs:28-33
    readonly property real cardPad: Theme.batteryCardPad
    readonly property real top: 12
    readonly property real row: Theme.batteryRow
    readonly property real ringLine: 3.5
    // theme.rs:1741 secondary_label #ebebf5b3 (Qt: #AARRGGBB)
    readonly property color secondaryLabel: "#b3ebebf5"
    readonly property string fontFamily: Theme.fontFamily

    anchors.fill: parent

    Item {
        id: line
        x: root.cardPad
        y: root.top
        width: parent.width - 2 * root.cardPad
        height: root.row

        Item {
            id: ringBox
            width: root.row
            height: root.row
            anchors.verticalCenter: parent.verticalCenter

            // The track (the colour at alpha 64, battery.rs ring()) and the fill.
            ProgressRing {
                anchors.fill: parent
                size: root.row
                progress: Power.percentage
                color: Power.colour
                thickness: root.ringLine
            }

            Image {
                anchors.centerIn: parent
                width: root.row / 2
                height: root.row / 2
                sourceSize.width: root.row
                sourceSize.height: root.row
                source: Power.icon
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        Column {
            anchors.left: ringBox.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 186

            Text {
                width: parent.width
                height: 16
                verticalAlignment: Text.AlignVCenter
                text: Power.title
                color: root.secondaryLabel
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: 500
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                height: 20
                verticalAlignment: Text.AlignVCenter
                text: Power.name
                color: "#ffffff"
                font.family: root.fontFamily
                font.pixelSize: 16
                font.weight: 600
                elide: Text.ElideRight
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 92
            height: 30
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: Power.percent + "%"
            color: Power.colour
            font.family: root.fontFamily
            font.pixelSize: 24
            font.weight: 600
        }
    }
}
