pragma ComponentBehavior: Bound

// Bars that move while playing and rest as dots while paused.
// Port of crates/shoji-island/src/island/now_playing.rs waveform() (:395-426).
// The Rust bars follow PipeWire FFT bands; there is no FFT here, so each bar
// does a smoothed random walk instead while playing.
// Compact: 6 bars, 3 wide, 2.5 gap, 14 tall (now_playing.rs:27).
// Expanded: 5 bars, 4 wide, 3 gap, 24 tall (now_playing.rs:45).

import QtQuick

Item {
    id: root

    property int bars: 6
    property real barWidth: 3
    property real gap: 2.5
    property real maxHeight: 14
    property bool playing: false
    // The artwork's accent in Rust, else the label colour (now_playing.rs:113-116).
    property color color: "#ffffff"
    // How often the walk takes a step (ms); heights ease between steps.
    property int stepMs: 140

    // An explicit size, so the bars start where the row does (now_playing.rs:404-406).
    implicitWidth: root.bars * root.barWidth + (root.bars - 1) * root.gap
    implicitHeight: root.maxHeight
    width: implicitWidth
    height: implicitHeight

    // 0..1 per bar.
    property var levels: []

    function step(): void {
        const next = [];
        for (let i = 0; i < root.bars; i++) {
            const prev = i < root.levels.length ? root.levels[i] : Math.random();
            // A walk pulled gently towards the middle, so bars neither stick
            // at the top nor flatline.
            let v = prev + (Math.random() - 0.5) * 0.55 + (0.5 - prev) * 0.15;
            next.push(Math.max(0.08, Math.min(1, v)));
        }
        root.levels = next;
    }

    Component.onCompleted: root.step()
    onBarsChanged: root.step()

    Timer {
        interval: root.stepMs
        repeat: true
        running: root.playing && root.visible
        onTriggered: root.step()
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap

        Repeater {
            model: root.bars

            Rectangle {
                id: bar
                required property int index

                readonly property real level: bar.index < root.levels.length ? root.levels[bar.index] : 0

                anchors.verticalCenter: parent.verticalCenter
                width: root.barWidth
                // Paused: a dot, as tall as it is wide (now_playing.rs:413-415).
                height: root.playing ? root.barWidth + bar.level * (root.maxHeight - root.barWidth) : root.barWidth
                radius: root.barWidth / 2
                color: root.color

                Behavior on height {
                    NumberAnimation {
                        duration: root.stepMs
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
}
