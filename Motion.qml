pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Springs, curves and timings of the Island. Paths are relative to crates/.
// Spring params are (response ms, damping ratio); components/Spring.qml turns
// them into stiffness = (2π / T)² and damping = 4πζ / T with unit mass
// (island-motion/src/lib.rs:21-27).
Singleton {
    id: root

    // ---------------------------------------------------------------- springs
    // island-motion/src/lib.rs:57-59 expand(): noctalia's islandExpand, 450 ms,
    // ζ 0.68 (about 5 % overshoot).
    readonly property real expandResponse: 450
    readonly property real expandDamping: 0.68
    // island-motion/src/lib.rs:62-64 collapse(): 360 ms / ζ 0.86.
    readonly property real collapseResponse: 360
    readonly property real collapseDamping: 0.86
    // shoji-island/src/island/spring.rs:11-13 drip(): the Island (and its
    // bubbles) coming out of / going back into the top edge, 240 ms / 0.74.
    readonly property real dripResponse: 240
    readonly property real dripDamping: 0.74
    // island-motion/src/lib.rs:66-69: a spring stops within this of its target
    // and slower than this (in the value's own units, per second).
    readonly property real restDistance: 0.0005
    readonly property real restVelocity: 0.005

    // ----------------------------------------------------------------- curves
    // shoji-island/src/island/spring.rs:20-28 Bezier constants, as
    // Easing.BezierSpline control lists [x1, y1, x2, y2, 1, 1].
    readonly property var standard: [0.2, 0.0, 0.0, 1.0, 1, 1]  // STANDARD
    readonly property var expand: [0.2, 0.8, 0.25, 1.0, 1, 1]   // EXPAND
    readonly property var leave: [0.4, 0.0, 1.0, 1.0, 1, 1]     // LEAVE

    // ------------------------------------------------------- content arrival
    // docs/DESIGN.md:339-352 and shoji-island/src/island/mod.rs:440-460:
    // arriving content follows its target 60 ms behind (an exponential
    // follow), fades, sharpens out of a 6 pt blur (sharp by 90 %) and drifts
    // 8 pt down out of the Island's top edge.
    readonly property real arrivalLagMs: 60
    readonly property real arrivalBlur: 6        // island/mod.rs:460 REVEAL_BLUR
    readonly property real arrivalSharpAt: 0.9   // island/mod.rs:455 reveal_blur
    readonly property real arrivalDrift: 8       // island/mod.rs:447 revealed
    // docs/DESIGN.md:360-363: a new main activity crossfades with the old one.
    readonly property int handoverMs: 420

    // ------------------------------------------------------------- pointer
    // shoji-island/src/island/mod.rs:1019-1023, :1072.
    readonly property int hoverOpenMs: 110       // HOVER_OPEN_MS
    readonly property int hoverCloseMs: 180      // HOVER_CLOSE_MS
    readonly property int collapseDelayMs: 400   // COLLAPSE_DELAY_MS
    readonly property int holdMs: 350            // HOLD_MS

    // -------------------------------------------------------------- timings
    readonly property int alertMs: 4000          // island/mod.rs:1115 ALERT_MS
    readonly property int arrivalMs: 4000        // island/activity.rs:76 ARRIVAL_MS
    readonly property int pausedLingerMs: 5 * 60 * 1000 // island/mod.rs:175
    readonly property int volumeNoticeMs: 1500   // island/notices.rs:282
    readonly property int soundNoticeMs: 2000    // island/notices.rs:281 (sound on / silent)
    readonly property int bannerExpiryMs: 5000   // island/notices.rs:284-293 (banner-like notices)
    readonly property int openBannerMs: 8000     // island/notices.rs:28
    // docs/DESIGN.md:391-395 marquee: wait 2 s, 24 pt/s, return 2x as fast.
    readonly property int marqueeWaitMs: 2000
    readonly property real marqueeSpeed: 24
    readonly property real marqueeReturnFactor: 2

    // ------------------------------------------------------------- helpers
    // island/mod.rs:412-415.
    function smoothstep(edge0: real, edge1: real, x: real): real {
        const t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)));
        return t * t * (3 - 2 * t);
    }

    function lerp(a: real, b: real, t: real): real {
        return a + (b - a) * t;
    }
}
