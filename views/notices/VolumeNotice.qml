pragma ComponentBehavior: Bound

// The volume (and brightness) notice: the Island is the OSD
// (crates/shoji-island/src/island/notices.rs:422-470). Symbol at the leading
// end, a 6 pt bar, the level in Nava's dark bubble at the trailing end
// (notices.rs:341-365). Dragging the bar sets the level.
// Shows Notices.current of kind "volume" or "brightness".

import QtQuick
import Quickshell
import qs
import qs.services

Item {
    id: root

    // now_playing.rs:20 COMPACT_WIDTH x mod.rs:159 IDLE height.
    readonly property real targetWidth: Theme.nowPlayingCompactWidth
    readonly property real targetHeight: Theme.idleHeight
    readonly property real targetRadius: targetHeight / 2

    // notices.rs:246-248 — GLYPH, LEAD_PAD (COMPACT_LEAD 32 - GLYPH/2), TRAIL_PAD.
    readonly property real glyph: Theme.noticeGlyph
    readonly property real leadPad: Theme.compactLead - glyph / 2
    readonly property real trailPad: Theme.noticeTrailPad
    // notices.rs:346 LEVEL_SLOT; bubble 24 tall, #1b1f40, figures #e9ebfe 12/700.
    readonly property real levelSlot: Theme.levelSlot
    readonly property real bubbleHeight: Theme.levelBubbleHeight
    readonly property color bubbleColor: Theme.levelBubble
    readonly property color bubbleText: Theme.levelText
    // theme.rs label tiers (iOS dark): label, tertiary (the empty track).
    readonly property color labelColor: "#ffffff"
    readonly property color trackColor: "#4debebf5" // #ebebf54d as Qt's #AARRGGBB
    // island-motion/src/fonts.rs:8-10.
    readonly property string fontFamily: Theme.fontFamily
    // notices.rs:449 — the bar takes what the symbol and the number leave.
    readonly property real track: Math.round(targetWidth - leadPad - glyph - 12 - 12 - levelSlot - trailPad)

    // The notice shown, kept while the view fades out after it ends.
    property var notice: ({
            kind: "volume",
            icon: "speaker",
            label: "0",
            level: 0
        })
    Binding on notice {
        when: Notices.current !== null && (Notices.current.kind === "volume" || Notices.current.kind === "brightness")
        value: Notices.current
        restoreMode: Binding.RestoreNone
    }

    readonly property bool brightness: notice.kind === "brightness"
    // While dragged, the level follows the pointer, not the notice.
    property real dragged: -1
    readonly property real level: dragged >= 0 ? dragged : Math.max(0, Math.min(1, notice.level))
    readonly property string shown: dragged >= 0 ? String(Math.round(dragged * 100)) : notice.label

    function apply(value: real): void {
        root.dragged = value;
        if (root.brightness)
            Brightness.set(value);
        else
            Audio.setVolume(value);
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: root.leadPad
        anchors.rightMargin: root.trailPad
        spacing: 12

        Item {
            width: root.glyph
            height: root.glyph
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                visible: !root.brightness
                source: Quickshell.shellDir + "/assets/island/" + (root.notice.icon || "speaker") + ".svg"
                sourceSize: Qt.size(root.glyph * 2, root.glyph * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            // A sun, drawn (the assets only have a grey one, sun-dark.svg):
            // its geometry is that file's (viewBox 32), at 20.
            Item {
                id: sun

                anchors.fill: parent
                visible: root.brightness

                Rectangle {
                    anchors.centerIn: parent
                    width: 5.2 * 2 * root.glyph / 32
                    height: width
                    radius: width / 2
                    color: root.labelColor
                }

                Repeater {
                    model: 8

                    Item {
                        id: ray

                        required property int index

                        anchors.fill: parent
                        rotation: ray.index * 45

                        Rectangle {
                            x: (sun.width - width) / 2
                            y: 3.5 * root.glyph / 32 - width / 2
                            width: 2.4 * root.glyph / 32
                            height: 3 * root.glyph / 32 + width
                            radius: width / 2
                            color: root.labelColor
                        }
                    }
                }
            }
        }

        // The bar, and the strip the pointer drags along (24 tall).
        Item {
            width: root.track
            height: 24
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: root.trackColor
                clip: true

                Rectangle {
                    width: Math.round(root.track * root.level)
                    height: parent.height
                    color: root.labelColor
                }
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPressed: mouse => root.apply(Math.max(0, Math.min(1, mouse.x / width)))
                onPositionChanged: mouse => {
                    if (pressed)
                        root.apply(Math.max(0, Math.min(1, mouse.x / width)));
                }
                onReleased: root.dragged = -1
                onCanceled: root.dragged = -1
            }
        }

        Rectangle {
            width: root.levelSlot
            height: root.bubbleHeight
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.bubbleColor

            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.shown
                color: root.bubbleText
                font.family: root.fontFamily
                font.pixelSize: 12
                font.weight: 700
                elide: Text.ElideRight
            }
        }
    }
}
