pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs

// The Island opened with nothing in it: noctalia's opened clock (1.4 x the
// idle one, 34 / 600) over the date (17 / 400, secondary label), centred in
// the expanded shape (island/mod.rs:169-171 EXPANDED 408 x 84, radius 42;
// :9600-9607).
Item {
    id: root

    property real targetWidth: Theme.expandedWidth
    property real targetHeight: Theme.expandedHeight
    property real targetRadius: Theme.expandedRadius

    anchors.fill: parent

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.clock(clock.date)
            color: Theme.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.expandedClockSize
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.longDate(clock.date)
            color: Theme.secondaryLabel
            font.family: Theme.fontFamily
            font.pixelSize: Theme.expandedDateSize
            font.weight: Font.Normal
        }
    }
}
