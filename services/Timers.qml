pragma Singleton
pragma ComponentBehavior: Bound

// One countdown timer (crates/shoji-island/src/island/timer.rs). The Rust
// Island runs several; this port keeps one, per the shared contract.
// Finishing: urgent, "Timer done", the theme's "complete" sound, and the
// finished state held 4 s (mod.rs:2342-2360 alert, ALERT_MS 4000) before it
// clears.
//
// IPC (target "island"):
//   qs ipc -c island call island timer 300
//   qs ipc -c island call island cancelTimer

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // mod.rs:1115 ALERT_MS
    readonly property int finishedHoldMs: Motion.alertMs
    // timer.rs:12 TINT
    readonly property color tint: Theme.timerTint

    // State (wall-clock ms internally, as timer.rs Timer)
    property real durationMs: 0
    property real startedAt: 0          // when started (ordering, arrival)
    property real endsAt: 0             // while running
    property real pausedRemainingMs: -1 // >= 0 while paused
    property real finishedAt: 0         // > 0 once finished
    property real now: Date.now()

    readonly property bool exists: durationMs > 0
    readonly property bool finished: exists && finishedAt > 0
    readonly property bool paused: exists && !finished && pausedRemainingMs >= 0
    readonly property bool running: exists && !finished && !paused

    readonly property real remainingMs: {
        if (!exists || finished)
            return 0;
        if (paused)
            return pausedRemainingMs;
        return Math.max(0, endsAt - now);
    }
    // Contract: seconds.
    readonly property real remaining: remainingMs / 1000
    readonly property real total: durationMs / 1000
    // 1 at the start, 0 when done (timer.rs TimerView::left).
    readonly property real progress: exists ? Math.max(0, Math.min(1, remainingMs / Math.max(1, durationMs))) : 0

    readonly property string display: formatRemaining(remainingMs)
    readonly property string displayMinimal: formatMinimal(remainingMs)
    readonly property string caption: finished ? "Timer done" : "Timer"

    // Emitted when the timer reaches zero, so the window can open (holdOpen).
    signal alerted()

    // timer.rs seconds_left: whole seconds, rounded up (0:01 until done).
    function secondsLeft(ms: real): int {
        return Math.max(0, Math.ceil(ms / 1000));
    }

    // timer.rs format_remaining: m:ss, or h:mm:ss from an hour.
    function formatRemaining(ms: real): string {
        const s = secondsLeft(ms);
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        const sec = s % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec);
    }

    // timer.rs format_minimal: at most five characters (4:59, 12:34, 2h).
    function formatMinimal(ms: real): string {
        const s = secondsLeft(ms);
        if (s >= 3600)
            return Math.floor((s + 1799) / 3600) + "h";
        const sec = s % 60;
        return Math.floor(s / 60) + ":" + (sec < 10 ? "0" : "") + sec;
    }

    function start(seconds: real): void {
        if (!(seconds > 0))
            return;
        const t = Date.now();
        now = t;
        durationMs = seconds * 1000;
        startedAt = t;
        endsAt = t + durationMs;
        pausedRemainingMs = -1;
        finishedAt = 0;
        clearTimer.stop();
    }

    function pause(): void {
        if (!running)
            return;
        now = Date.now();
        pausedRemainingMs = Math.max(0, endsAt - now);
    }

    function resume(): void {
        if (!paused)
            return;
        now = Date.now();
        endsAt = now + pausedRemainingMs;
        pausedRemainingMs = -1;
    }

    function toggle(): void {
        if (running)
            pause();
        else
            resume();
    }

    function cancel(): void {
        clearTimer.stop();
        durationMs = 0;
        startedAt = 0;
        endsAt = 0;
        pausedRemainingMs = -1;
        finishedAt = 0;
    }

    function finish(): void {
        finishedAt = Date.now();
        // crate::sounds::play("complete", "Timer")
        sound.running = true;
        clearTimer.restart();
        alerted();
    }

    // Ticks while running; 250 ms keeps the rounded-up seconds on time.
    Timer {
        interval: 250
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            if (root.now >= root.endsAt)
                root.finish();
        }
    }

    // The finished state is held, then the activity goes.
    Timer {
        id: clearTimer
        interval: root.finishedHoldMs
        onTriggered: root.cancel()
    }

    Process {
        id: sound
        command: ["canberra-gtk-play", "-i", "complete", "-d", "Timer"]
    }

    // VERIFY: only one IpcHandler may own target "island"; if another service
    // adds one, merge these functions into it.
    IpcHandler {
        target: "island"

        function timer(seconds: int): void {
            root.start(seconds);
        }

        function cancelTimer(): void {
            root.cancel();
        }
    }
}
