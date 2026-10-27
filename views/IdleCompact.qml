pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.components

// The idle Island: the time in a 2.5 : 1 capsule (island/mod.rs:155-159
// IDLE 160 x 64), 24 / 600 (island/mod.rs:1065 IDLE_CLOCK, :9578), its
// figures centred a point above the capsule's middle (:1036 TIME_MIDDLE).
// At the end, noctalia's notification badge (:1039-1043, :9660-9700): a
// bell with an unread dot in the accent, or Do Not Disturb's moon.
Item {
    id: root

    property real targetWidth: Theme.idleWidth
    property real targetHeight: Theme.idleHeight

    // WP5: bind these from the Notifs service (unread notifications, and
    // Do Not Disturb if it gets one). The moon wins over the bell (mod.rs:9279).
    property bool unread: false
    property bool doNotDisturb: false

    anchors.fill: parent

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: time
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: Theme.timeMiddle
        text: Theme.clock(clock.date)
        color: Theme.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.idleClockSize
        font.weight: Font.DemiBold
    }

    // The badge's slot: 24 across, 10 in from the capsule's end.
    Item {
        id: indicator
        readonly property bool showing: root.unread || root.doNotDisturb
        width: Theme.indicator
        height: Theme.indicator
        x: root.width - Theme.indicatorEnd - width
        y: Math.round(Theme.timeMiddle - Theme.indicator / 2)
        opacity: showing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }

        Icon {
            anchors.centerIn: parent
            size: Theme.indicatorGlyph
            name: root.doNotDisturb ? "moon-purple" : "bell"
        }

        // The unread dot at the bell's top right, in the accent's light end.
        Rectangle {
            visible: !root.doNotDisturb
            x: (parent.width + Theme.indicatorGlyph) / 2 - width
            y: (parent.height - Theme.indicatorGlyph) / 2
            width: Theme.unreadDot
            height: Theme.unreadDot
            radius: Theme.unreadDot / 2
            color: Theme.accent
        }
    }
}
