pragma ComponentBehavior: Bound

// An app's notification as a banner: noctalia's 360 x 64, a 32 icon 22 in,
// app name / title / the body's first line, its actions as buttons under it
// (crates/shoji-island/src/island/notices.rs:241-244, :752-756, :839-871,
// :1078-1108). A click runs its default action, else dismisses it; held
// (HOLD 350 ms, mod.rs:1019) it opens out (Notifs.open -> BannerExpanded).
// The pointer on it holds it (Notifs.pauseExpiry).

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

Item {
    id: root

    // notices.rs:241-243 MESSAGE_WIDTH/HEIGHT, :254 BUTTONS_HEIGHT.
    readonly property real cardHeight: Theme.bannerHeight
    readonly property real buttonsHeight: Theme.noticeButtonsHeight
    readonly property real targetWidth: Theme.bannerWidth
    readonly property real targetHeight: cardHeight + (snap.buttons.length > 0 ? buttonsHeight : 0)
    // mod.rs:8937 — half the height, at most EXPANDED_RADIUS 42 (mod.rs:171).
    readonly property real targetRadius: Math.min(targetHeight / 2, Theme.expandedRadius)

    // notices.rs:752-756 PAD, ICON, ICON_RADIUS.
    readonly property real pad: Theme.bannerIconInset
    readonly property real iconSize: Theme.bannerIcon
    readonly property real iconRadius: Theme.bannerIconRadius
    readonly property real textWidth: targetWidth - 2 * pad - iconSize - 12
    // mod.rs:1019 HOLD.
    readonly property int holdMs: Motion.holdMs
    // theme.rs label tiers (iOS dark).
    readonly property color labelColor: Theme.label
    readonly property color secondaryLabel: "#99ebebf5" // #ebebf599; Qt reads #AARRGGBB
    readonly property color tertiaryLabel: "#4debebf5" // #ebebf54d
    readonly property string fontFamily: Theme.fontFamily

    // What it shows, kept while the view fades out after the banner goes.
    property var snap: ({
            appName: "",
            summary: "",
            body: "",
            icon: "",
            buttons: []
        })
    Binding on snap {
        when: Notifs.current !== null
        value: ({
                appName: Notifs.current.appName,
                summary: Notifs.current.summary,
                body: Notifs.current.body,
                icon: Notifs.iconSource(Notifs.current),
                buttons: Notifs.buttons(Notifs.current)
            })
        restoreMode: Binding.RestoreNone
    }

    readonly property string initial: snap.appName.length > 0 ? snap.appName.charAt(0).toUpperCase() : "•"
    readonly property string firstLine: snap.body.split("\n")[0]

    HoverHandler {
        onHoveredChanged: Notifs.pauseExpiry(hovered)
    }
    Component.onDestruction: Notifs.pauseExpiry(false)

    Item {
        id: card

        width: root.targetWidth
        height: root.cardHeight

        ClippingRectangle {
            id: icon

            x: root.pad
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: root.iconSize
            radius: root.iconRadius
            color: root.snap.icon === "" ? "#3a3a3c" : "transparent"

            Image {
                anchors.fill: parent
                visible: root.snap.icon !== ""
                source: root.snap.icon
                sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }

            Text {
                anchors.fill: parent
                visible: root.snap.icon === ""
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.initial
                color: "#ffffff"
                font.family: root.fontFamily
                font.pixelSize: 18
                font.weight: 600
            }
        }

        Column {
            x: root.pad + root.iconSize + 12
            anchors.verticalCenter: parent.verticalCenter
            width: root.textWidth
            spacing: 1

            Text {
                width: parent.width
                height: 14 // round(11 * 1.25)
                verticalAlignment: Text.AlignVCenter
                text: root.snap.appName
                color: root.tertiaryLabel
                font.family: root.fontFamily
                font.pixelSize: 11
                font.weight: 500
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                width: parent.width
                height: 18
                verticalAlignment: Text.AlignVCenter
                text: root.snap.summary
                color: root.labelColor
                font.family: root.fontFamily
                font.pixelSize: 14
                font.weight: 600
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
            Text {
                width: parent.width
                height: 15
                visible: root.firstLine !== ""
                verticalAlignment: Text.AlignVCenter
                text: root.firstLine
                color: root.secondaryLabel
                font.family: root.fontFamily
                font.pixelSize: 12
                font.weight: 400
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
        }

        // Its default action, else away; held, it opens out.
        MouseArea {
            property bool held: false

            anchors.fill: parent
            pressAndHoldInterval: root.holdMs
            onPressed: held = false
            onPressAndHold: {
                held = true;
                Notifs.setOpen(true);
            }
            onClicked: {
                if (!held)
                    Notifs.invokeDefault();
            }
        }
    }

    // notices.rs:839-863 — buttons 30 tall, 8 apart, the row 42 tall.
    Row {
        id: buttonRow

        readonly property int count: root.snap.buttons.length
        readonly property real each: count > 0 ? Math.floor((root.targetWidth - 2 * root.pad - spacing * (count - 1)) / count) : 0

        x: root.pad
        y: root.cardHeight
        height: root.buttonsHeight
        spacing: 8
        visible: count > 0

        Repeater {
            model: root.snap.buttons

            Rectangle {
                id: button

                required property var modelData

                width: buttonRow.each
                height: 30
                radius: 15
                color: tap.pressed ? "#3dffffff" : "#24ffffff" // #AARRGGBB

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: button.modelData.text
                    color: root.labelColor
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.weight: 600
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: tap

                    anchors.fill: parent
                    onClicked: Notifs.invokeAction(button.modelData.identifier)
                }
            }
        }
    }
}
