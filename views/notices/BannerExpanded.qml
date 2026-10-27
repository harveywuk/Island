pragma ComponentBehavior: Bound

// A banner held open (iOS's expanded notification): the expanded Island's
// width, the same icon and app name, a title of up to three lines and the
// body's first fourteen, its buttons under them
// (crates/shoji-island/src/island/notices.rs:752-794, :1110-1140).
// Shown while Notifs.open; it stays at least 8 s (Notifs.openBannerMs) and
// while the pointer is on it. A click runs its default action, else
// dismisses it.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

Item {
    id: root

    // notices.rs:759-763 — OPEN_WIDTH (mod.rs:169 EXPANDED.0), OPEN_TOP,
    // OPEN_BOTTOM, OPEN_TITLE_LINES, OPEN_BODY_LINES.
    readonly property real targetWidth: Theme.openBannerWidth
    readonly property real openTop: Theme.openBannerPad
    readonly property real openBottom: Theme.openBannerPad
    readonly property int titleLines: 3
    readonly property int bodyLines: 14
    // notices.rs:241-243, :254.
    readonly property real minHeight: Theme.bannerHeight
    readonly property real buttonsHeight: Theme.noticeButtonsHeight
    readonly property bool hasButtons: snap.buttons.length > 0
    // notices.rs:781-787 — the app's name (14), the title's lines (18 + 1),
    // after a gap the body's (16 + 1).
    readonly property real textHeight: 14 + title.lineCount * 19 + (hasBody ? 4 + body.lineCount * 17 : 0)
    readonly property real cardHeight: Math.ceil(Math.max(openTop + textHeight + openBottom, minHeight))
    readonly property real targetHeight: cardHeight + (hasButtons ? buttonsHeight : 0)
    // mod.rs:8937 — at most EXPANDED_RADIUS 42.
    readonly property real targetRadius: Math.min(targetHeight / 2, Theme.expandedRadius)

    readonly property real pad: Theme.bannerIconInset
    readonly property real iconSize: Theme.bannerIcon
    readonly property real iconRadius: Theme.bannerIconRadius
    readonly property real textWidth: targetWidth - 2 * pad - iconSize - 12
    readonly property color labelColor: Theme.label
    readonly property color secondaryLabel: "#99ebebf5" // #ebebf599; Qt reads #AARRGGBB
    readonly property color tertiaryLabel: "#4debebf5" // #ebebf54d
    readonly property string fontFamily: Theme.fontFamily

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
    readonly property string bodyText: snap.body.trim()
    readonly property bool hasBody: bodyText !== ""

    HoverHandler {
        onHoveredChanged: Notifs.pauseExpiry(hovered)
    }
    Component.onDestruction: Notifs.pauseExpiry(false)

    Item {
        id: card

        width: root.targetWidth
        height: root.cardHeight

        ClippingRectangle {
            x: root.pad
            y: root.openTop
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
            y: root.openTop
            width: root.textWidth
            spacing: 0

            Text {
                width: parent.width
                height: 14
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
                id: title

                width: parent.width
                text: root.snap.summary
                color: root.labelColor
                font.family: root.fontFamily
                font.pixelSize: 14
                font.weight: 600
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: root.titleLines
                elide: Text.ElideRight
                lineHeightMode: Text.FixedHeight
                lineHeight: 19
            }

            Item {
                width: 1
                height: root.hasBody ? 4 : 0
            }

            Text {
                id: body

                width: parent.width
                visible: root.hasBody
                text: root.bodyText
                color: root.secondaryLabel
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: 400
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: root.bodyLines
                elide: Text.ElideRight
                lineHeightMode: Text.FixedHeight
                lineHeight: 17
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Notifs.invokeDefault()
        }
    }

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
