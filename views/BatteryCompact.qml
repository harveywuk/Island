pragma ComponentBehavior: Bound

// Compact battery (crates/shoji-island/src/island/battery.rs compact): the
// device leading (a bolt while charging), its charge as a ring trailing with
// the percentage inside.

import QtQuick
import Quickshell
import qs
import qs.services
import qs.components

Item {
    id: root

    // now_playing.rs:20 COMPACT_WIDTH (every compact activity), mod.rs:159 IDLE.1
    property real targetWidth: Theme.nowPlayingCompactWidth
    property real targetHeight: Theme.idleHeight
    property real targetRadius: targetHeight / 2

    // mod.rs:164-167 COMPACT_RING 36, COMPACT_LEAD 32
    readonly property real ring: Theme.compactRing
    readonly property real lead: Theme.compactLead
    // battery.rs compact(): ring thickness 2.5
    readonly property real ringLine: 2.5
    readonly property string fontFamily: Theme.fontFamily

    anchors.fill: parent

    // The glyph, COMPACT_RING - 10 in a COMPACT_RING - 2 box, centred 32 in.
    Item {
        width: root.ring - 2
        height: root.ring - 2
        x: root.lead - width / 2
        anchors.verticalCenter: parent.verticalCenter

        Image {
            anchors.centerIn: parent
            width: root.ring - 10
            height: root.ring - 10
            sourceSize.width: 2 * width
            sourceSize.height: 2 * height
            source: Power.icon
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // The ring, centred 32 in from the right end.
    Item {
        width: root.ring
        height: root.ring
        x: parent.width - root.lead - width / 2
        anchors.verticalCenter: parent.verticalCenter

        // The track (the colour at alpha 64, battery.rs ring()) and the fill.
        ProgressRing {
            anchors.fill: parent
            size: root.ring
            progress: Power.percentage
            color: Power.colour
            thickness: root.ringLine
        }

        Text {
            anchors.centerIn: parent
            text: Power.percent
            color: "#ffffff"
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.ring * 0.36)
            font.weight: 600
        }
    }
}
