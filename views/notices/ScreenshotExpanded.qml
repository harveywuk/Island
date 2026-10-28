pragma ComponentBehavior: Bound

// A saved screenshot held open (ScreenshotNotice held, Capture.open): the
// expanded Island's width, a larger thumbnail, its name, and four 44 px
// round buttons: Copy, Open, Show in Folder, Delete (macOS's floating
// thumbnail's menu; the actions are file_actions.rs's and capture.rs's).
// Delete moves it to the Trash and lets the notice go. It stays while the
// pointer is on it, then Capture.openMs after it leaves.
//
// The layout is this port's own (the Rust Island has no expanded
// screenshot): the notice's tokens (notices.rs:684-749) at a larger size,
// the round buttons as capturing.rs's 44 px ones.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services

Item {
    id: root

    // mod.rs:169 EXPANDED.0
    readonly property real targetWidth: Theme.expandedWidth
    readonly property real pad: 18
    // The thumbnail fits in this (the notice's 96 x 60 at the card's width).
    readonly property real thumbBoxWidth: targetWidth - 2 * pad
    readonly property real thumbBoxHeight: 200
    readonly property real thumbRadius: 10
    readonly property real textGap: 12
    readonly property real textHeight: 20 + 1 + 16
    readonly property real buttonsGap: 14
    // capturing.rs:165-172, :256-259 — 44 round, 24 symbols, #ffffff2e; a
    // caption under each.
    readonly property real button: 44
    readonly property real glyph: 24
    readonly property real captionHeight: 14
    readonly property real buttonsHeight: button + 6 + captionHeight
    readonly property real targetHeight: pad + fitHeight + textGap + textHeight + buttonsGap + buttonsHeight + pad
    // mod.rs:8937 — at most EXPANDED_RADIUS 42.
    readonly property real targetRadius: Math.min(targetHeight / 2, Theme.expandedRadius)

    readonly property color labelColor: Theme.label
    readonly property color secondaryLabel: "#99ebebf5" // #ebebf599; Qt reads #AARRGGBB
    readonly property string fontFamily: Theme.fontFamily

    property var snap: ({
            path: "",
            copied: false,
            failed: false
        })
    Binding on snap {
        when: Capture.last !== null
        value: Capture.last
        restoreMode: Binding.RestoreNone
    }

    // A note under the name after Copy ("Copied to the clipboard").
    property string note: ""

    // capture.rs:667-674 fit.
    readonly property bool imageReady: thumb.status === Image.Ready && thumb.implicitWidth > 0 && thumb.implicitHeight > 0
    readonly property real fitScale: imageReady ? Math.min(thumbBoxWidth / thumb.implicitWidth, thumbBoxHeight / thumb.implicitHeight) : 1
    readonly property real fitWidth: imageReady ? Math.max(1, Math.round(thumb.implicitWidth * fitScale)) : thumbBoxWidth
    readonly property real fitHeight: imageReady ? Math.max(1, Math.round(thumb.implicitHeight * fitScale)) : thumbBoxHeight * 0.5625

    width: targetWidth
    height: targetHeight

    HoverHandler {
        onHoveredChanged: Capture.holdOpen(hovered)
    }

    ClippingRectangle {
        id: frame

        x: Math.round((root.targetWidth - root.fitWidth) / 2)
        y: root.pad
        width: root.fitWidth
        height: root.fitHeight
        radius: root.thumbRadius
        color: "#24ffffff"

        Image {
            id: thumb

            anchors.fill: parent
            source: root.snap.path !== "" ? Capture.fileUri(root.snap.path) : ""
            // Not PreserveAspectCrop: that would crop the decode to sourceSize
            // and lose the proportions the fit reads.
            sourceSize: Qt.size(root.thumbBoxWidth * Screen.devicePixelRatio, root.thumbBoxHeight * Screen.devicePixelRatio)
            fillMode: Image.Stretch
            asynchronous: true
            cache: false
            smooth: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.act("open")
        }
    }
    Rectangle {
        anchors.fill: frame
        radius: root.thumbRadius
        color: "transparent"
        border.width: 1
        border.color: "#40ffffff" // notices.rs:709 #ffffff40
    }

    Column {
        x: root.pad
        y: root.pad + root.fitHeight + root.textGap
        width: root.targetWidth - 2 * root.pad
        spacing: 1

        Text {
            width: parent.width
            height: 20
            verticalAlignment: Text.AlignVCenter
            text: "Screenshot Saved"
            color: root.labelColor
            font.family: root.fontFamily
            font.pixelSize: 16
            font.weight: 600
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            width: parent.width
            height: 16
            verticalAlignment: Text.AlignVCenter
            text: root.note !== "" ? root.note : Capture.fileName(root.snap.path)
            color: root.secondaryLabel
            font.family: root.fontFamily
            font.pixelSize: 13
            font.weight: 400
            elide: Text.ElideMiddle
            maximumLineCount: 1
            textFormat: Text.PlainText
        }
    }

    function act(what: string): void {
        const path = root.snap.path;
        if (path === "")
            return;
        switch (what) {
        case "copy":
            Capture.copyFile(path);
            root.note = "Copied to the clipboard";
            return;
        case "open":
            Capture.openFile(path);
            break;
        case "show":
            Capture.showInFolder(path);
            break;
        case "delete":
            // Clears Capture.last, Capture.open and the notice.
            Capture.trash(path);
            return;
        }
        Capture.setOpen(false);
        Notices.clear();
    }

    Row {
        id: buttons

        readonly property var actions: [
            {
                id: "copy",
                icon: "copy",
                text: "Copy",
                tint: "#2effffff"
            },
            {
                id: "open",
                icon: "file",
                text: "Open",
                tint: "#2effffff"
            },
            {
                id: "show",
                icon: "folder",
                text: "Show in Folder",
                tint: "#2effffff"
            },
            {
                id: "delete",
                icon: "trash",
                text: "Delete",
                tint: "#3dff453a" // #ff453a at 3d, as capturing.rs:168
            }
        ]
        readonly property real each: Math.floor((root.targetWidth - 2 * root.pad) / actions.length)

        x: root.pad
        y: root.targetHeight - root.pad - root.buttonsHeight
        height: root.buttonsHeight

        Repeater {
            model: buttons.actions

            Item {
                id: cell

                required property var modelData

                width: buttons.each
                height: root.buttonsHeight

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.button
                    height: root.button
                    radius: root.button / 2
                    // #ffffff2e, lighter while pressed (#ffffff47, capture.rs:327).
                    color: tap.pressed ? (cell.modelData.id === "delete" ? "#66ff453a" : "#47ffffff") : cell.modelData.tint

                    Icon {
                        anchors.centerIn: parent
                        name: cell.modelData.icon
                        size: root.glyph
                    }
                }

                Text {
                    y: root.button + 6
                    width: parent.width
                    height: root.captionHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: cell.modelData.text
                    color: root.secondaryLabel
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.weight: 500
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: tap

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.act(cell.modelData.id)
                }
            }
        }
    }
}
