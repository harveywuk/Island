pragma ComponentBehavior: Bound

// A compact notice: its symbol at the leading end, its words at the
// trailing end (crates/shoji-island/src/island/notices.rs:367-384,
// symbol_and_words). Used for kind "generic" (microphone, layout, scripts).
// notice.width widens it (e.g. 340, notices.rs:252); notice.color tints the
// words.

import QtQuick
import Quickshell
import qs
import qs.services

Item {
    id: root

    property var notice: ({
            kind: "generic",
            icon: "",
            label: "",
            color: "",
            width: 0
        })
    Binding on notice {
        when: Notices.current !== null && Notices.current.kind === "generic"
        value: Notices.current
        restoreMode: Binding.RestoreNone
    }

    // now_playing.rs:20 COMPACT_WIDTH x mod.rs:159 IDLE height.
    readonly property real targetWidth: notice.width > 0 ? notice.width : Theme.nowPlayingCompactWidth
    readonly property real targetHeight: Theme.idleHeight
    readonly property real targetRadius: targetHeight / 2

    readonly property real glyph: Theme.noticeGlyph
    readonly property real leadPad: Theme.compactLead - glyph / 2
    readonly property real trailPad: Theme.noticeTrailPad
    readonly property string fontFamily: Theme.fontFamily

    Image {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: root.leadPad
        anchors.verticalCenter: parent.verticalCenter
        width: root.glyph
        height: root.glyph
        visible: (root.notice.icon ?? "") !== ""
        source: visible ? Quickshell.shellDir + "/assets/island/" + root.notice.icon + ".svg" : ""
        sourceSize: Qt.size(root.glyph * 2, root.glyph * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // notices.rs:371 — the words take what the symbol leaves, 12 between.
    Text {
        anchors.right: parent.right
        anchors.rightMargin: root.trailPad
        anchors.verticalCenter: parent.verticalCenter
        width: root.targetWidth - root.leadPad - root.glyph - 12 - root.trailPad
        horizontalAlignment: Text.AlignRight
        text: root.notice.label ?? ""
        color: (root.notice.color ?? "") !== "" ? root.notice.color : "#ffffff"
        font.family: root.fontFamily
        font.pixelSize: 15
        font.weight: 600
        elide: Text.ElideRight
    }
}
