pragma ComponentBehavior: Bound

// macOS's floating thumbnail, in the Island: the picture, then where it went
// (crates/shoji-island/src/island/notices.rs:684-749 screenshot_view; size
// notices.rs:268, (EXPANDED.0, 84)). A click opens a saved one; held (HOLD
// 350 ms, mod.rs:1019) it opens out (Capture.setOpen -> ScreenshotExpanded).
// Reads Capture.last, kept while the view fades out.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services

Item {
    id: root

    // notices.rs:268 — the expanded Island's width (mod.rs:169), 84 tall.
    readonly property real targetWidth: Theme.expandedWidth
    readonly property real targetHeight: 84
    // mod.rs:8937 — half the height, at most EXPANDED_RADIUS 42.
    readonly property real targetRadius: Math.min(targetHeight / 2, Theme.expandedRadius)

    // notices.rs:743 padding_x 18, gap 14; :684 THUMB 96 x 60.
    readonly property real pad: 18
    readonly property real gap: 14
    readonly property real thumbWidth: 96
    readonly property real thumbHeight: 60
    // notices.rs:720 — the symbol's circle for Copied / Failed.
    readonly property real circle: 48
    readonly property int holdMs: Motion.holdMs
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

    readonly property bool saved: !snap.failed && !snap.copied && snap.path !== ""
    // notices.rs:690-697
    readonly property string title: snap.failed ? "Screenshot Failed" : snap.copied ? "Screenshot Copied" : "Screenshot Saved"
    readonly property string detail: snap.failed ? "The screen could not be captured" : snap.copied ? "On the clipboard" : Capture.fileName(snap.path)

    // capture.rs:667-674 fit — the picture's own proportions inside 96 x 60.
    readonly property bool imageReady: thumb.status === Image.Ready && thumb.implicitWidth > 0 && thumb.implicitHeight > 0
    readonly property real fitScale: imageReady ? Math.min(thumbWidth / thumb.implicitWidth, thumbHeight / thumb.implicitHeight) : 1
    readonly property real fitWidth: imageReady ? Math.max(1, Math.round(thumb.implicitWidth * fitScale)) : thumbWidth
    readonly property real fitHeight: imageReady ? Math.max(1, Math.round(thumb.implicitHeight * fitScale)) : thumbHeight
    readonly property real pictureWidth: saved ? fitWidth : circle
    readonly property real textWidth: targetWidth - 2 * pad - pictureWidth - gap

    width: targetWidth
    height: targetHeight

    // The picture's slot: pictureWidth x 60, its content centred.
    Item {
        id: slot

        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        width: root.pictureWidth
        height: root.thumbHeight

        // notices.rs:703-713 — clipped by a rounded box (r 6) with a 1 px
        // #ffffff40 edge. VERIFY: the Rust 0,2,8 #00000080 shadow is left out.
        ClippingRectangle {
            id: frame

            anchors.centerIn: parent
            visible: root.saved
            width: root.fitWidth
            height: root.fitHeight
            radius: 6
            color: "#24ffffff"

            Image {
                id: thumb

                anchors.fill: parent
                source: root.saved ? Capture.fileUri(root.snap.path) : ""
                // Decoded small; with both set (and not PreserveAspectCrop,
                // which would crop to them) it keeps its aspect, so the
                // implicit size gives the proportions for the fit.
                sourceSize: Qt.size(root.thumbWidth * 2 * Screen.devicePixelRatio, root.thumbHeight * 2 * Screen.devicePixelRatio)
                fillMode: Image.Stretch
                asynchronous: true
                cache: false
                smooth: true
            }
        }
        Rectangle {
            anchors.fill: frame
            visible: root.saved
            radius: 6
            color: "transparent"
            border.width: 1
            border.color: "#40ffffff" // #ffffff40
        }

        // notices.rs:715-729 — Copied / Failed: the symbol in a circle.
        Rectangle {
            anchors.centerIn: parent
            visible: !root.saved
            width: root.circle
            height: root.circle
            radius: root.circle / 2
            color: root.snap.failed ? "#33ff453a" : "#24ffffff" // #ff453a33 / #ffffff24

            Icon {
                anchors.centerIn: parent
                name: "screenshot"
                size: 26
            }
        }
    }

    Column {
        x: root.pad + root.pictureWidth + root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: root.textWidth
        spacing: 1

        Text {
            width: parent.width
            height: 20 // round(16 * 1.25)
            verticalAlignment: Text.AlignVCenter
            text: root.title
            color: root.labelColor
            font.family: root.fontFamily
            font.pixelSize: 16
            font.weight: 600
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            width: parent.width
            height: 16 // round(13 * 1.25)
            verticalAlignment: Text.AlignVCenter
            text: root.detail
            color: root.secondaryLabel
            font.family: root.fontFamily
            font.pixelSize: 13
            font.weight: 400
            elide: Text.ElideMiddle
            maximumLineCount: 1
            textFormat: Text.PlainText
        }
    }

    // A click opens a saved one (notices.rs:739, mod.rs:3168), else lets
    // the notice go; held, a saved one opens out.
    MouseArea {
        property bool held: false

        anchors.fill: parent
        pressAndHoldInterval: root.holdMs
        cursorShape: root.saved ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: held = false
        onPressAndHold: {
            if (!root.saved)
                return;
            held = true;
            Capture.setOpen(true);
        }
        onClicked: {
            if (held)
                return;
            if (root.saved)
                Capture.openFile(root.snap.path);
            Notices.clear();
        }
    }
}
