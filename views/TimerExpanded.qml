pragma ComponentBehavior: Bound

// Expanded timer (crates/shoji-island/src/island/timer.rs expanded): pause or
// resume and cancel on the left, the caption and time left on the right.

import QtQuick
import Quickshell
import qs
import qs.services

Item {
    id: root

    // mod.rs:169 EXPANDED.0, timer.rs:14 EXPANDED_HEIGHT, mod.rs:171 EXPANDED_RADIUS
    property real targetWidth: Theme.expandedWidth
    property real targetHeight: Theme.timerExpandedHeight
    property real targetRadius: Theme.expandedRadius

    // theme.rs:1741 secondary_label #ebebf5b3 (Qt: #AARRGGBB)
    readonly property color secondaryLabel: "#b3ebebf5"
    readonly property string fontFamily: Theme.fontFamily

    anchors.fill: parent

    component RoundButton: Rectangle {
        id: button
        property string icon
        signal clicked()
        width: 44
        height: 44
        radius: 22
        scale: area.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Image {
            anchors.centerIn: parent
            width: 22
            height: 22
            sourceSize.width: 44
            sourceSize.height: 44
            source: Quickshell.shellDir + "/assets/island/" + button.icon
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        MouseArea {
            id: area
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        // A finished timer has nothing to pause.
        RoundButton {
            visible: !Timers.finished
            // timer.rs: the tint at alpha 0x3d
            color: Qt.rgba(Timers.tint.r, Timers.tint.g, Timers.tint.b, 0x3d / 255)
            icon: Timers.running ? "pause-orange.svg" : "play-orange.svg"
            onClicked: Timers.toggle()
        }

        RoundButton {
            color: "#2effffff" // timer.rs #ffffff2e
            icon: "xmark.svg"
            onClicked: Timers.cancel()
        }
    }

    Column {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        width: 170

        Text {
            width: parent.width
            height: 16
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: Timers.caption
            color: root.secondaryLabel
            font.family: root.fontFamily
            font.pixelSize: 13
            font.weight: 500
            elide: Text.ElideLeft
        }

        Text {
            width: parent.width
            height: 40
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: Timers.display
            color: Timers.tint
            font.family: root.fontFamily
            font.pixelSize: 36
            font.weight: 500
            font.features: ({ "tnum": 1 }) // VERIFY: font.features needs Qt 6.6+
        }
    }
}
