pragma ComponentBehavior: Bound

// Compact timer (crates/shoji-island/src/island/timer.rs compact): the orange
// timer symbol leading, centred 32 in (concentric with the capsule's end),
// the time left trailing, 16 in.

import QtQuick
import Quickshell
import qs
import qs.services

Item {
    id: root

    // now_playing.rs:20 COMPACT_WIDTH (every compact activity), mod.rs:159 IDLE.1
    property real targetWidth: Theme.nowPlayingCompactWidth
    property real targetHeight: Theme.idleHeight
    property real targetRadius: targetHeight / 2

    // mod.rs:164-167 COMPACT_RING 36, COMPACT_LEAD 32
    readonly property real ring: Theme.compactRing
    readonly property real lead: Theme.compactLead
    // adwaita/mod.rs:514 TEXT fonts (fonts.rs:8)
    readonly property string fontFamily: Theme.fontFamily

    anchors.fill: parent

    Item {
        id: leading
        width: root.ring
        height: root.ring
        x: root.lead - root.ring / 2
        anchors.verticalCenter: parent.verticalCenter

        Image {
            anchors.centerIn: parent
            width: 24
            height: 24
            sourceSize.width: 48
            sourceSize.height: 48
            source: Quickshell.shellDir + "/assets/island/timer.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 56
        height: 18
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: Timers.display
        color: Timers.tint
        font.family: root.fontFamily
        font.pixelSize: 15
        font.weight: 600
        font.features: ({ "tnum": 1 }) // VERIFY: font.features needs Qt 6.6+
    }
}
