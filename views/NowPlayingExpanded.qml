pragma ComponentBehavior: Bound

// Now Playing, expanded: artwork, title, artist and waveform; progress;
// transport controls. Fixed at the expanded size so nothing reflows while
// the Island grows. Port of crates/shoji-island/src/island/now_playing.rs
// expanded() (:236-289), progress() (:428-536), controls() (:538-596).
// A click on the artwork or title raises the player's window (Rust opens its
// big card, not ported); pressing the track scrubs, letting go seeks.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services

Item {
    id: root

    // island/mod.rs:169 EXPANDED width; now_playing.rs:33 EXPANDED_HEIGHT.
    property real targetWidth: Theme.expandedWidth
    property real targetHeight: Theme.nowPlayingExpandedHeight
    // island/mod.rs:171 EXPANDED_RADIUS.
    property real targetRadius: Theme.expandedRadius

    // now_playing.rs:38-44
    readonly property real margin: Theme.nowPlayingExpandedMargin
    readonly property real artSize: Theme.nowPlayingExpandedArt
    readonly property real timeWidth: Theme.nowPlayingTimeWidth
    readonly property real artCorner: Theme.artworkCorner
    readonly property real trackWidth: root.targetWidth - 2 * root.margin - 2 * root.timeWidth - 2 * 8 // 280
    // now_playing.rs:45 EXPANDED_WAVE
    readonly property int waveBars: 5
    readonly property real waveBarWidth: 4
    readonly property real waveGap: 3
    readonly property real waveHeight: 24
    readonly property real waveWidth: root.waveBars * root.waveBarWidth + (root.waveBars - 1) * root.waveGap
    // now_playing.rs:49-54 CARD_TEXT = 408 - 40 - 52 - 24 - 32 = 260
    readonly property real cardText: root.targetWidth - 2 * root.margin - root.artSize - 12 - 12 - root.waveWidth
    // now_playing.rs:55 CARD_TYPE: 16/600 title, 16/400 artist.
    readonly property real cardSize: 16
    // now_playing.rs:61 SEEK_STEPS
    readonly property int seekSteps: 48

    // theme.rs:1723-1725 (OSD_FG white; DIM 0.55, DIMMER 0.30 from adwaita/mod.rs:155,162).
    readonly property color labelColor: Theme.label
    readonly property color secondaryColor: Theme.secondaryLabel
    readonly property color tertiaryColor: Theme.tertiaryLabel
    // island/mod.rs:10637 accent fill, deep to light.
    readonly property color accentDeep: Theme.accentDeep
    readonly property color accentLight: Theme.accent
    readonly property color artBackground: "#3a3a3c" // now_playing.rs:353
    // island-motion/src/fonts.rs:8
    readonly property string fontFamily: Theme.fontFamily

    // While the track is held: where it is dragged to (0..1), else -1.
    property real scrub: -1

    readonly property real shownPosition: root.scrub >= 0 && Media.length > 0 ? Media.length * root.scrub : Media.position

    // now_playing.rs:598-603: m:ss, or h:mm:ss from an hour.
    function formatTime(seconds: real): string {
        const total = Math.floor(Math.max(0, seconds));
        const h = Math.floor(total / 3600);
        const m = Math.floor(total / 60) % 60;
        const s = total % 60;
        const ss = (s < 10 ? "0" : "") + s;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + ss;
        return m + ":" + ss;
    }

    function iconPath(name: string): string {
        return Quickshell.shellDir + "/assets/island/" + name + ".svg";
    }

    anchors.fill: parent

    // ---- Header: artwork, title/artist, waveform ----------------------------

    ClippingRectangle { // VERIFY: Quickshell.Widgets.ClippingRectangle clips children to its radius
        id: art
        x: root.margin
        y: root.margin
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
            source: root.iconPath("music")
        }
    }

    Column {
        id: card
        x: art.x + root.artSize + 12
        anchors.verticalCenter: art.verticalCenter
        width: root.cardText
        spacing: 1

        Marquee {
            width: root.cardText
            height: Math.round(root.cardSize * 1.2)
            text: Media.title
            pixelSize: root.cardSize
            weight: 600
            family: root.fontFamily
            color: root.labelColor
        }

        Marquee {
            width: root.cardText
            height: Math.round(root.cardSize * 1.2)
            text: Media.artist
            pixelSize: root.cardSize
            weight: 400
            family: root.fontFamily
            color: root.secondaryColor
        }
    }

    // The artwork and title together raise the player (now_playing.rs:242-245).
    MouseArea {
        x: art.x
        y: art.y
        width: card.x + card.width - art.x
        height: root.artSize
        enabled: Media.canRaise
        cursorShape: Qt.PointingHandCursor
        onClicked: Media.raise()
    }

    Waveform {
        x: root.targetWidth - root.margin - width
        anchors.verticalCenter: art.verticalCenter
        bars: root.waveBars
        barWidth: root.waveBarWidth
        gap: root.waveGap
        maxHeight: root.waveHeight
        playing: Media.playing
        color: root.labelColor
    }

    // ---- Progress: elapsed, track, remaining -------------------------------

    Item {
        id: progress
        x: root.margin
        y: root.margin + root.artSize + 14
        width: root.targetWidth - 2 * root.margin
        height: 14

        Text {
            x: 0
            width: root.timeWidth
            height: 14
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            text: root.formatTime(root.shownPosition)
            color: root.secondaryColor
            font.family: root.fontFamily
            font.pixelSize: 12
            font.weight: 500
        }

        Item {
            id: track
            x: root.timeWidth + 8
            width: root.trackWidth
            height: 14

            ClippingRectangle {
                x: 0
                y: 4.5
                width: track.width
                height: 5
                radius: 2.5
                color: root.tertiaryColor

                Rectangle {
                    height: 5
                    width: Media.length > 0 ? Math.max(0, Math.min(1, root.shownPosition / Media.length)) * track.width : 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.accentDeep }
                        GradientStop { position: 1; color: root.accentLight }
                    }
                }
            }

            // Seek targets, taller than the bar (now_playing.rs:477-503): the
            // track is cut into SEEK_STEPS steps; press starts a scrub at the
            // step's middle, moving while held follows it, release seeks.
            MouseArea {
                id: seekArea
                x: 0
                y: -6
                width: track.width
                height: 26
                enabled: Media.canSeek
                cursorShape: Media.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                preventStealing: true

                function stepAt(px: real): real {
                    const step = Math.max(0, Math.min(root.seekSteps - 1, Math.floor(px / (track.width / root.seekSteps))));
                    return (step + 0.5) / root.seekSteps;
                }

                onPressed: mouse => root.scrub = seekArea.stepAt(mouse.x)
                onPositionChanged: mouse => {
                    if (seekArea.pressed)
                        root.scrub = seekArea.stepAt(mouse.x);
                }
                onReleased: {
                    if (root.scrub >= 0)
                        Media.seek(root.scrub);
                    root.scrub = -1;
                }
                onCanceled: root.scrub = -1
            }
        }

        Text {
            x: track.x + track.width + 8
            width: root.timeWidth
            height: 14
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignRight
            text: Media.length > 0 ? "-" + root.formatTime(Media.length - root.shownPosition) : "--:--"
            color: root.secondaryColor
            font.family: root.fontFamily
            font.pixelSize: 12
            font.weight: 500
        }
    }

    // ---- Transport: previous, play/pause, next (now_playing.rs:538-596) ------

    component TransportButton: MouseArea {
        id: button
        // A full path: inline components do not see the outer file's ids.
        property url source
        property real iconSize: 28
        property bool allowed: true

        width: 44
        height: 32
        enabled: button.allowed
        opacity: button.allowed ? 1 : 0.35
        cursorShape: Qt.PointingHandCursor

        Image {
            anchors.centerIn: parent
            width: button.iconSize
            height: button.iconSize
            sourceSize.width: button.iconSize * 2
            sourceSize.height: button.iconSize * 2
            source: button.source
            scale: button.pressed ? 0.9 : 1

            Behavior on scale {
                NumberAnimation { duration: 120 }
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: progress.y + progress.height + 12
        height: 32
        spacing: 28

        TransportButton {
            source: root.iconPath("backward")
            iconSize: 28
            allowed: Media.canPrevious
            onClicked: Media.previous()
        }

        TransportButton {
            source: root.iconPath(Media.playing ? "pause" : "play")
            iconSize: 30
            allowed: Media.canTogglePlaying
            onClicked: Media.togglePlaying()
        }

        TransportButton {
            source: root.iconPath("forward")
            iconSize: 28
            allowed: Media.canNext
            onClicked: Media.next()
        }
    }
}
