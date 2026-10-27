pragma ComponentBehavior: Bound

// Now Playing, compact: artwork at the leading edge, waveform at the
// trailing edge; the space between is where the camera sits.
// Port of crates/shoji-island/src/island/now_playing.rs compact() (:156-219).
// The new-song announcement (ANNOUNCE_WIDTH 420) is not ported in this pass.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services

Item {
    id: root

    // now_playing.rs:20 COMPACT_WIDTH; island/mod.rs:159 IDLE height.
    property real targetWidth: Theme.nowPlayingCompactWidth
    property real targetHeight: Theme.idleHeight
    property real targetRadius: root.targetHeight / 2

    // now_playing.rs:36-37, :28, :42
    readonly property real margin: Theme.nowPlayingCompactMargin
    readonly property real artSize: Theme.nowPlayingCompactArt
    readonly property real waveEnd: 4
    readonly property real artCorner: Theme.artworkCorner
    // now_playing.rs:353 placeholder background behind artwork.
    readonly property color artBackground: "#3a3a3c"
    // theme.rs:1723 label (OSD_FG, white).
    readonly property color labelColor: Theme.label

    anchors.fill: parent

    ClippingRectangle { // VERIFY: Quickshell.Widgets.ClippingRectangle clips children to its radius
        id: art
        x: root.margin
        anchors.verticalCenter: parent.verticalCenter
        width: root.artSize
        height: root.artSize
        radius: root.artSize * root.artCorner
        color: root.artBackground

        Image {
            id: cover
            anchors.fill: parent
            visible: cover.status === Image.Ready
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: root.artSize * 2
            sourceSize.height: root.artSize * 2
            asynchronous: true
            cache: true
        }

        Image {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            width: root.artSize * 0.6
            height: width
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            source: Quickshell.shellDir + "/assets/island/music.svg"
        }
    }

    Waveform {
        anchors.right: parent.right
        anchors.rightMargin: root.margin + root.waveEnd
        anchors.verticalCenter: parent.verticalCenter
        bars: 6
        barWidth: 3
        gap: 2.5
        maxHeight: 14
        playing: Media.playing
        color: root.labelColor
    }
}
