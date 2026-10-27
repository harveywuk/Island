pragma Singleton
pragma ComponentBehavior: Bound

// Which activities the Island shows, in order (crates/shoji-island/src/island/activity.rs).
// `list` holds ids from {"timer", "music", "battery"}: the first has the
// Island (compact), the next two become bubbles (right, then left; activity.rs place()).
//
// Order (activity.rs:84 order): urgent first (a finished timer), then one
// that has just arrived (ARRIVAL_MS 4 s, even over music), then music
// playing (it keeps the bar), then the rest; newest first within each.
// No "brought forward" pin and no indicators in this port.

import QtQuick
import Quickshell
import qs
import qs.services

Singleton {
    id: root

    // activity.rs:76 ARRIVAL_MS
    readonly property int arrivalMs: Motion.arrivalMs

    property var list: []

    readonly property string main: list.length > 0 ? list[0] : ""
    readonly property var bubbles: list.slice(1, 3)

    // Presence of each activity.
    readonly property bool timerPresent: Timers.running || Timers.paused || Timers.finished
    readonly property bool musicPresent: Media.active
    readonly property bool batteryPresent: Power.active

    // When each became present (wall-clock ms); 0 while absent.
    property real timerSince: 0
    property real musicSince: 0
    property real batterySince: 0

    onTimerPresentChanged: { timerSince = timerPresent ? Timers.startedAt || Date.now() : 0; recompute(); }
    onMusicPresentChanged: { musicSince = musicPresent ? Date.now() : 0; recompute(); }
    onBatteryPresentChanged: { batterySince = batteryPresent ? Date.now() : 0; recompute(); }

    Connections {
        target: Timers
        // A new countdown over an old one arrives again.
        function onStartedAtChanged() {
            if (root.timerPresent && Timers.startedAt > 0)
                root.timerSince = Timers.startedAt;
            root.recompute();
        }
        function onFinishedChanged() { root.recompute(); }
    }

    Connections {
        target: Media
        // VERIFY: Media.playing is WP2's "music playing" flag (keeps_bar).
        function onPlayingChanged() { root.recompute(); }
    }

    function recompute(): void {
        const now = Date.now();
        const entries = [];
        if (timerPresent)
            entries.push({ id: "timer", since: timerSince, urgent: Timers.finished, keepsBar: false });
        if (musicPresent)
            entries.push({ id: "music", since: musicSince, urgent: false, keepsBar: Media.playing === true });
        if (batteryPresent)
            entries.push({ id: "battery", since: batterySince, urgent: false, keepsBar: false });

        let nextExpiry = Infinity;
        for (const e of entries) {
            const left = e.since + arrivalMs - now;
            e.arriving = left > 0;
            if (left > 0)
                nextExpiry = Math.min(nextExpiry, left);
        }

        // activity.rs rank: (!urgent, !arriving, !keeps_bar || arriving), then newest first.
        const rank = e => [e.urgent ? 0 : 1, e.arriving ? 0 : 1, (!e.keepsBar || e.arriving) ? 1 : 0];
        entries.sort((a, b) => {
            const ra = rank(a), rb = rank(b);
            for (let i = 0; i < ra.length; i++) {
                if (ra[i] !== rb[i])
                    return ra[i] - rb[i];
            }
            return b.since - a.since;
        });

        const ordered = entries.map(e => e.id);
        if (ordered.join() !== list.join())
            list = ordered;

        // Re-order when the next arrival ends.
        if (nextExpiry !== Infinity) {
            arrivalTimer.interval = Math.max(1, Math.ceil(nextExpiry) + 1);
            arrivalTimer.restart();
        } else {
            arrivalTimer.stop();
        }
    }

    Timer {
        id: arrivalTimer
        onTriggered: root.recompute()
    }

    Component.onCompleted: recompute()
}
