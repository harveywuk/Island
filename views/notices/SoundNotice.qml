pragma ComponentBehavior: Bound

// iOS's Silent Mode notice: the speaker at the leading end, "Silent" in red
// or "Sound On" at the trailing end (crates/shoji-island/src/island/notices.rs:400-421).
// Shows Notices.current of kind "silent" or "soundOn".

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

    // notices.rs:246-248.
    readonly property real glyph: Theme.noticeGlyph
    readonly property real leadPad: Theme.compactLead - glyph / 2
    readonly property real trailPad: Theme.noticeTrailPad
    // notices.rs:165 iOS systemRed (dark).
    readonly property color red: "#ff453a"
    readonly property string fontFamily: Theme.fontFamily

    property var notice: ({
            kind: "soundOn",
            icon: "speaker",
            label: "Sound On"
        })
    Binding on notice {
        when: Notices.current !== null && (Notices.current.kind === "silent" || Notices.current.kind === "soundOn")
        value: Notices.current
        restoreMode: Binding.RestoreNone
    }

    readonly property bool silent: notice.kind === "silent"

    Image {
        anchors.left: parent.left
        anchors.leftMargin: root.leadPad
        anchors.verticalCenter: parent.verticalCenter
        width: root.glyph
        height: root.glyph
        source: Quickshell.shellDir + "/assets/island/" + (root.silent ? "speaker-slash" : "speaker") + ".svg"
        sourceSize: Qt.size(root.glyph * 2, root.glyph * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: root.trailPad
        anchors.verticalCenter: parent.verticalCenter
        width: 120
        horizontalAlignment: Text.AlignRight
        text: root.silent ? "Silent" : "Sound On"
        color: root.silent ? root.red : "#ffffff"
        font.family: root.fontFamily
        font.pixelSize: 15
        font.weight: 600
        elide: Text.ElideRight
    }
}
