pragma ComponentBehavior: Bound

// One line of text that scrolls when it does not fit, as iOS's Now Playing:
// it waits, scrolls to its end, waits, and goes back, again and again while
// it shows. Port of crates/shoji-island/src/island/marquee.rs.
// Text that fits sits as a label aligned by `horizontalAlignment`; text that
// does not starts at the left and scrolls.

import QtQuick
import qs

Item {
    id: root

    property string text: ""
    property color color: "#ffffff"
    property real pixelSize: 16
    property int weight: Font.Normal
    property string family: Theme.fontFamily // island-motion/src/fonts.rs:8
    property int horizontalAlignment: Text.AlignLeft
    // Reduce Motion: rests at its start (marquee.rs:149-152).
    property bool reduceMotion: false

    // marquee.rs:11-17
    readonly property real speed: Motion.marqueeSpeed
    readonly property real returnSpeed: Motion.marqueeSpeed * Motion.marqueeReturnFactor
    readonly property real waitMs: Motion.marqueeWaitMs
    readonly property real ease: 0.15

    // Whole points, so it rests on the pixel grid at both ends (marquee.rs:144).
    readonly property real overflow: Math.max(0, Math.ceil(label.implicitWidth - root.width))
    readonly property bool scrolls: root.overflow >= 1 && !root.reduceMotion

    property real elapsedMs: 0

    implicitHeight: Math.round(root.pixelSize * 1.2)
    clip: true

    // New text, or text shown again, starts from the beginning (marquee.rs:86-98).
    onTextChanged: root.elapsedMs = 0
    onVisibleChanged: if (root.visible) root.elapsedMs = 0

    function easeAt(t: real): real {
        const e = root.ease;
        t = Math.max(0, Math.min(1, t));
        const scale = 1 / (1 - e);
        if (t < e)
            return scale * t * t / (2 * e);
        if (t > 1 - e)
            return 1 - scale * (1 - t) * (1 - t) / (2 * e);
        return scale * (t - e / 2);
    }

    // marquee.rs:51-67
    function offsetAt(elapsed: real, overflow: real): real {
        if (overflow <= 0.5 || elapsed <= 0)
            return 0;
        const out = overflow / root.speed * 1000;
        const back = overflow / root.returnSpeed * 1000;
        const at = elapsed % (root.waitMs + out + root.waitMs + back);
        if (at < root.waitMs)
            return 0;
        if (at < root.waitMs + out)
            return overflow * root.easeAt((at - root.waitMs) / out);
        if (at < 2 * root.waitMs + out)
            return overflow;
        return overflow * (1 - root.easeAt((at - 2 * root.waitMs - out) / back));
    }

    FrameAnimation {
        running: root.scrolls && root.visible
        onTriggered: root.elapsedMs += frameTime * 1000
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: root.scrolls ? -root.offsetAt(root.elapsedMs, root.overflow) : 0
        // Its whole width while it scrolls, so nothing cuts it (marquee.rs:177).
        width: root.scrolls ? Math.ceil(implicitWidth) + 2 : root.width
        text: root.text
        color: root.color
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        textFormat: Text.PlainText
        maximumLineCount: 1
        elide: root.scrolls ? Text.ElideNone : Text.ElideRight
        horizontalAlignment: root.scrolls ? Text.AlignLeft : root.horizontalAlignment
    }
}
