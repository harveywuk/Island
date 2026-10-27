pragma ComponentBehavior: Bound

// Now Playing as a bubble (island/mod.rs:162 BUBBLE 48): the artwork in a
// circle, or the waveform when there is none.

import QtQuick
import Quickshell.Widgets
import qs
import qs.services
import qs.components

Item {
    id: root

    property real targetWidth: Theme.bubbleSize
    property real targetHeight: Theme.bubbleSize

    readonly property real artSize: Theme.compactRing

    anchors.fill: parent

    ClippingRectangle { // VERIFY: Quickshell.Widgets.ClippingRectangle clips children to its radius
        anchors.centerIn: parent
        width: root.artSize
        height: root.artSize
        radius: root.artSize / 2
        color: "transparent"
        visible: cover.status === Image.Ready

        Image {
            id: cover
            anchors.fill: parent
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: root.artSize * 2
            sourceSize.height: root.artSize * 2
            asynchronous: true
            cache: true
        }
    }

    Waveform {
        anchors.centerIn: parent
        visible: cover.status !== Image.Ready
        bars: 4
        barWidth: 3
        gap: 2.5
        maxHeight: 14
        playing: Media.playing
        color: Theme.label
    }
}
