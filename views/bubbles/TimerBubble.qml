pragma ComponentBehavior: Bound

// The timer as a bubble beside the capsule (island/mod.rs:162 BUBBLE 48):
// its ring of time left in the timer's tint with the timer symbol inside.

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
        progress: Timers.progress
        color: Timers.tint

        Icon {
            anchors.centerIn: parent
            name: "timer"
            size: 18
        }
    }
}
